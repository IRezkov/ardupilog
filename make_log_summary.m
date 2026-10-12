% =========================
% CONFIGURATION
% =========================
global DEBUG_MAX_LOGS MIN_DURATION_SEC MIN_SPEED_MPS MIN_THROTTLE_OUT

rootDir = uigetdir(pwd, 'Выберите рабочую папку с логами');
if isequal(rootDir, 0)
    error('make_log_summary:FolderSelectionCancelled', ...
        'Выбор рабочей папки отменён.');
end

scriptDir = fileparts(mfilename('fullpath'));

% сначала проверим наличие папки functions
if exist(fullfile(scriptDir, 'functions'), 'dir')
    addpath(fullfile(scriptDir, 'functions'));
else
    warning('Functions folder not found under %s', scriptDir);
end

SEARCH_SUBDIRS = true;    % true = search under subfolders, false = only current folder
DEBUG_MAX_LOGS = inf;      % set to Inf to process all logs
MIN_DURATION_SEC = 20;   % minimum useful log duration
MIN_SPEED_MPS = 1;       % minimum speed to count as movement
MIN_THROTTLE_OUT = 0.05; % minimum throttle output to count as active control

outDir = rootDir;
maxLogs = DEBUG_MAX_LOGS;

global DEBUG_MAX_LOGS MIN_DURATION_SEC MIN_SPEED_MPS MIN_THROTTLE_OUT

if isempty(outDir)
    outDir = rootDir;
end
if isempty(maxLogs)
    maxLogs = DEBUG_MAX_LOGS;
end

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

binFiles = find_bin_files(rootDir, SEARCH_SUBDIRS);
if isempty(binFiles)
    error('No .bin files found under %s', rootDir);
end

binFiles = sort_bin_files_by_start_time(binFiles);

if isfinite(maxLogs) && maxLogs > 0 && numel(binFiles) > maxLogs
    binFiles = binFiles(1:maxLogs);
    fprintf('Debug mode: processing only first %d log(s).\n', maxLogs);
end

processedLogs = {};
paramMaps = {};
allSegments = {};
allModeSegments = {};

for i = 1:numel(binFiles)
    filePath = binFiles{i};
    try
        log = Ardupilog(filePath);
        if ismethod(log, 'deleteEmptyMsgs')
            log = log.deleteEmptyMsgs;
        end
    catch ME
        warning('Skipping %s: %s', filePath, ME.message);
        continue;
    end

    rec = summarize_single_log(log, filePath);
    processedLogs{end + 1} = rec;
    paramMaps{end + 1} = struct('FileName', rec.FileName, 'Map', extract_last_param_map(log), 'History', extract_param_history(log));
    % Segments must be built now, while this log is still parsed in memory;
    % keeping every Log object alive until the end (as before) is what ran
    % out of memory on large recursive folders.
    allSegments{end + 1} = build_log_parameter_mode_segments(log, rec, false);
    allModeSegments{end + 1} = build_log_parameter_mode_segments(log, rec, true);
    clear log;
end

if isempty(processedLogs)
    error('No logs were successfully read with Ardupilog in %s', rootDir);
end

%%
% --- Сохраняем полные данные ДО фильтрации ---
allProcessedLogs = processedLogs;
allParamMaps     = paramMaps;

% --- Фильтруем для первой таблицы (summary) ---
[filteredLogs, filteredParamMaps, keepMask] = filter_meaningful_logs(...
    processedLogs, paramMaps, ...
    MIN_DURATION_SEC, MIN_SPEED_MPS, MIN_THROTTLE_OUT);
filteredSegments = allSegments(keepMask);

if isempty(filteredLogs)
    error('No meaningful logs remained after filtering short / inactive runs in %s', rootDir);
end

% --- Первая таблица: отфильтрованные логи + сегменты по режимам и параметрам ---
summaryTable = build_segmented_summary_table(filteredLogs, filteredParamMaps, filteredSegments);
if isempty(summaryTable)
    summaryTable = struct2table([filteredLogs{:}], 'AsArray', true);
    if height(summaryTable) > 0 && ismember('BootTimeUTC', summaryTable.Properties.VariableNames)
        summaryTable = sortrows(summaryTable, 'BootTimeUTC');
    else
        summaryTable = sortrows(summaryTable, 'FileName');
    end
end
if height(summaryTable) > 0 && ismember('BootTimeUTC', summaryTable.Properties.VariableNames)
    summaryTable = sortrows(summaryTable, 'BootTimeUTC');
else
    summaryTable = sortrows(summaryTable, 'FileName');
end
summaryTable = attach_changed_params_to_summary(summaryTable, allParamMaps);
summaryTable = filter_summary_segments(summaryTable, MIN_DURATION_SEC, MIN_SPEED_MPS);

% --- Вторая таблица: ВСЕ логи + изменения, включая изменения внутри PARM одного лога ---
paramTable = build_changed_param_table(allParamMaps, true);

allSummaryTable = build_segmented_summary_table(allProcessedLogs, allParamMaps, allModeSegments);
if isempty(allSummaryTable)
    allSummaryTable = struct2table([allProcessedLogs{:}], 'AsArray', true);
    if height(allSummaryTable) > 0 && ismember('BootTimeUTC', allSummaryTable.Properties.VariableNames)
        allSummaryTable = sortrows(allSummaryTable, 'BootTimeUTC');
    else
        allSummaryTable = sortrows(allSummaryTable, 'FileName');
    end
end
if height(allSummaryTable) > 0 && ismember('BootTimeUTC', allSummaryTable.Properties.VariableNames)
    allSummaryTable = sortrows(allSummaryTable, 'BootTimeUTC');
else
    allSummaryTable = sortrows(allSummaryTable, 'FileName');
end
allSummaryTable = attach_changed_params_to_summary(allSummaryTable, allParamMaps);

% --- Запись отчёта ---
write_summary_markdown(summaryTable, paramTable, outDir, 'summary_report.md', allSummaryTable);

fprintf('\nSummary report written to:\n');
fprintf('  %s\n', fullfile(outDir, 'summary_report.md'));

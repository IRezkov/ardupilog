function results = analyze_auto_runs(rootDir, outputDir)
% ANALYZE_AUTO_RUNS Анализирует все проезды в режиме AUTO в .bin-логах.
%
% Для каждого непрерывного интервала MODE=AUTO вычисляются:
%   TurnRateRMSE       - ошибка следования TurnRate за DesTurnRate;
%   TargetErrorRMSE    - среднеквадратичная ошибка по траектории, м;
%   QualityScore       - общая оценка от 0 до 100, где больше означает лучше.
%
% Итоговая оценка рассчитывается по формуле:
%
% $$
% Score = \frac{100}{1 + 0.4\frac{TurnRateRMSE}{10} +
%                         0.6\frac{TargetErrorRMSE}{5}}
% $$
%
% Вес ошибки TurnRate составляет 40 процентов, а вес ошибки траектории -
% 60 процентов. Опорные масштабы равны 10 град/с и 5 м соответственно.
% Они приводят две ошибки к сопоставимому масштабу перед объединением.
%
% Время StartTimeS/EndTimeS отсчитывается от начала лога (как в plot2.m),
% DurationS - длительность проезда в секундах.
%
% Значения параметров, действовавшие в начале каждого AUTO-проезда,
% сравниваются с предыдущим обработанным проездом. После каждого проезда
% результат дописывается в auto_run_quality.csv, набор параметров - в
% auto_run_parameter_sets.mat (для дальнейшего анализа), а checkpoint
% сохраняется в auto_run_quality_checkpoint.mat, поэтому длительный анализ
% можно прервать без потери готовых результатов.

    if nargin < 1 || isempty(rootDir)
        rootDir = pwd;
    end
    if nargin < 2 || isempty(outputDir)
        outputDir = rootDir;
    end

    scriptDir = fileparts(mfilename('fullpath'));
    addpath(fullfile(scriptDir, 'functions'));
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    config = struct('turnRateScale', 10, 'targetErrorScale', 5, ...
        'turnWeight', 0.4, 'targetWeight', 0.6);
    csvPath = fullfile(outputDir, 'auto_run_quality.csv');
    matPath = fullfile(outputDir, 'auto_run_quality_checkpoint.mat');
    paramSetsPath = fullfile(outputDir, 'auto_run_parameter_sets.mat');
    binFiles = find_bin_files(rootDir, true);
    binFiles = sort_bin_files_by_start_time(binFiles);

    results = empty_result_table();
    parameterSets = struct('LogFile', {}, 'StartTimeS', {}, 'Parameters', {});
    previousParameters = containers.Map('KeyType', 'char', 'ValueType', 'any');
    write_csv_header(csvPath);

    for fileIndex = 1:numel(binFiles)
        filePath = binFiles{fileIndex};
        fprintf('[%d/%d] %s\n', fileIndex, numel(binFiles), filePath);
        try
            log = Ardupilog(filePath);
            if ismethod(log, 'deleteEmptyMsgs')
                log = log.deleteEmptyMsgs;
            end
            clean_msg(log, 'MODE', 10, 0);
            clean_msg(log, 'PARM', 10, 0);
            clean_msg(log, 'STER', 10, 0);
            clean_msg(log, 'PSCN', 10, 0);
            clean_msg(log, 'PSCE', 10, 0);
            logStartTime = compute_log_start_time(log);
            autoRuns = find_auto_runs(log);
            for runIndex = 1:numel(autoRuns)
                run = autoRuns(runIndex);
                metrics = measure_auto_run(log, run.StartTime, run.EndTime, config);
                if ~metrics.IsValid
                    continue;
                end

                currentParameters = parameters_at_time(log, run.StartTime);
                changedText = describe_parameter_changes(previousParameters, currentParameters);
                relativeRun = struct('StartTime', run.StartTime - logStartTime, ...
                    'EndTime', run.EndTime - logStartTime);
                row = make_result_row(filePath, runIndex, relativeRun, metrics, changedText);
                results = [results; row]; %#ok<AGROW>
                append_result_csv(csvPath, row);
                previousParameters = currentParameters;
                parameterSets(end + 1) = struct('LogFile', basename_from_path(filePath), ...
                    'RunIndex', runIndex, 'StartTimeS', relativeRun.StartTime, ...
                    'Parameters', currentParameters); %#ok<AGROW>
                save(matPath, 'results', 'previousParameters', 'config', '-v7.3');
                save(paramSetsPath, 'parameterSets', '-v7.3');
            end
            clear log autoRuns
        catch exception
            warning('Skipping %s: %s', filePath, exception.message);
        end
    end
    save(matPath, 'results', 'previousParameters', 'config', '-v7.3');
    save(paramSetsPath, 'parameterSets', '-v7.3');
end

function startTime = compute_log_start_time(log)
    ster = get_field_value(log, 'STER');
    times = double(get_field_value(ster, 'TimeS'));
    times = times(isfinite(times));
    if ~isempty(times)
        startTime = times(1);
        return;
    end
    startTime = 0;
end

function files = find_bin_files(rootDir, recursive)
    if nargin < 2
        recursive = true;
    end
    entries = dir(fullfile(rootDir, '*.bin'));
    files = cell(numel(entries), 1);
    for i = 1:numel(entries)
        files{i} = fullfile(entries(i).folder, entries(i).name);
    end
    if recursive
        folders = dir(rootDir);
        for i = 1:numel(folders)
            if folders(i).isdir && ~ismember(folders(i).name, {'.', '..'})
                files = [files; find_bin_files(fullfile(rootDir, folders(i).name), true)]; %#ok<AGROW>
            end
        end
    end
end

function runs = find_auto_runs(log)
    runs = struct('StartTime', {}, 'EndTime', {});
    modeObj = get_field_value(log, 'MODE');
    if isempty(modeObj)
        return;
    end
    modeTimes = double(get_field_value(modeObj, 'TimeS'));
    modeValues = double(get_field_value(modeObj, 'Mode'));
    if isempty(modeTimes) || numel(modeTimes) ~= numel(modeValues)
        return;
    end
    [modeTimes, order] = sort(modeTimes(:));
    modeValues = modeValues(order(:));
    logEnd = compute_log_end_time(log);
    if isempty(logEnd) || ~isfinite(logEnd)
        logEnd = max(modeTimes);
    end
    i = 1;
    while i <= numel(modeTimes)
        if modeValues(i) ~= 10
            i = i + 1;
            continue;
        end
        startIndex = i;
        i = i + 1;
        while i <= numel(modeTimes) && modeValues(i) == 10
            i = i + 1;
        end
        endTime = logEnd;
        if i <= numel(modeTimes)
            endTime = modeTimes(i);
        end
        if endTime > modeTimes(startIndex)
            runs(end + 1) = struct('StartTime', modeTimes(startIndex), ...
                'EndTime', endTime); %#ok<AGROW>
        end
    end
end

function metrics = measure_auto_run(log, startTime, endTime, config)
    metrics = struct('TurnRMSE', NaN, 'TargetRMSE', NaN, 'Score', NaN, 'IsValid', false);
    ster = get_field_value(log, 'STER');
    turnTime = double(get_field_value(ster, 'TimeS'));
    desired = double(get_field_value(ster, 'DesTurnRate'));
    actual = double(get_field_value(ster, 'TurnRate'));
    turnMask = turnTime >= startTime & turnTime < endTime & ...
        isfinite(turnTime) & isfinite(desired) & isfinite(actual);
    if nnz(turnMask) < 2
        return;
    end
    turnError = actual(turnMask) - desired(turnMask);
    metrics.TurnRMSE = sqrt(mean(turnError.^2));

    trajectory = build_target_trajectory(log, 0);
    if isempty(trajectory.time)
        return;
    end
    targetMask = trajectory.time >= startTime & trajectory.time < endTime & ...
        isfinite(trajectory.errorM);
    if nnz(targetMask) < 2
        return;
    end
    metrics.TargetRMSE = sqrt(mean(trajectory.errorM(targetMask).^2));
    normalizedError = config.turnWeight * metrics.TurnRMSE / config.turnRateScale + ...
        config.targetWeight * metrics.TargetRMSE / config.targetErrorScale;
    metrics.Score = 100 / (1 + normalizedError);
    metrics.IsValid = isfinite(metrics.Score);
end

function parameters = parameters_at_time(log, timeValue)
    parameters = containers.Map('KeyType', 'char', 'ValueType', 'any');
    parameterListPath = fullfile(fileparts(mfilename('fullpath')), ...
        'functions', 'mini_report_params.txt');
    allowedNames = readlines(parameterListPath);
    allowedNames = strtrim(allowedNames);
    allowedNames = allowedNames(allowedNames ~= "" & ~startsWith(allowedNames, "#"));
    allowedNames = upper(cellstr(allowedNames));

    parm = get_field_value(log, 'PARM');
    names = get_field_value(parm, 'Name');
    values = get_field_value(parm, 'Value');
    times = get_field_value(parm, 'TimeS');
    if isempty(names) || isempty(values) || isempty(times)
        return;
    end
    names = flatten_param_names(names);
    values = flatten_param_values(values);
    times = double(times(:));
    count = min([numel(names), numel(values), numel(times)]);
    for i = 1:count
        if isfinite(times(i)) && times(i) <= timeValue
            key = normalize_param_name(names{i});
            if ~isempty(key) && ismember(upper(key), allowedNames)
                parameters(key) = values{i};
            end
        end
    end
end

function text = describe_parameter_changes(previous, current)
    names = keys(current);
    changed = {};
    for i = 1:numel(names)
        name = names{i};
        if ~isKey(previous, name) || ~values_equal(previous(name), current(name))
            changed{end + 1} = sprintf('%s=%s', name, value_to_string(current(name))); %#ok<AGROW>
        end
    end
    text = strjoin(sort(changed), '; ');
end

function row = make_result_row(filePath, runIndex, run, metrics, changedText)
    durationS = run.EndTime - run.StartTime;
    row = table({basename_from_path(filePath)}, runIndex, run.StartTime, run.EndTime, durationS, ...
        metrics.TurnRMSE, metrics.TargetRMSE, metrics.Score, {changedText}, ...
        'VariableNames', {'LogFile', 'RunIndex', 'StartTimeS', 'EndTimeS', 'DurationS', ...
        'TurnRateRMSE', 'TargetErrorRMSE', 'QualityScore', 'ChangedParameters'});
end

function tableValue = empty_result_table()
    tableValue = table(cell(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
        zeros(0, 1), zeros(0, 1), zeros(0, 1), cell(0, 1), ...
        'VariableNames', {'LogFile', 'RunIndex', 'StartTimeS', 'EndTimeS', 'DurationS', ...
        'TurnRateRMSE', 'TargetErrorRMSE', 'QualityScore', 'ChangedParameters'});
end

function write_csv_header(csvPath)
    if isfile(csvPath)
        delete(csvPath);
    end
    fid = fopen(csvPath, 'w');
    fprintf(fid, 'LogFile,RunIndex,StartTimeS,EndTimeS,DurationS,TurnRateRMSE,TargetErrorRMSE,QualityScore,ChangedParameters\n');
    fclose(fid);
end

function append_result_csv(csvPath, row)
    fid = fopen(csvPath, 'a');
    changed = strrep(row.ChangedParameters{1}, '"', '""');
    fprintf(fid, '"%s",%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,"%s"\n', ...
        strrep(row.LogFile{1}, '"', '""'), row.RunIndex, row.StartTimeS, row.EndTimeS, ...
        row.DurationS, row.TurnRateRMSE, row.TargetErrorRMSE, row.QualityScore, changed);
    fclose(fid);
end
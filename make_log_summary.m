% =========================
% CONFIGURATION
% =========================
global DEBUG_MAX_LOGS MIN_DURATION_SEC MIN_SPEED_MPS MIN_THROTTLE_OUT

DEBUG_MAX_LOGS = 3;      % set to Inf to process all logs
MIN_DURATION_SEC = 20;   % minimum useful log duration
MIN_SPEED_MPS = 1;       % minimum speed to count as movement
MIN_THROTTLE_OUT = 0.05; % minimum throttle output to count as active control

rootDir = pwd;
outDir = rootDir;
maxLogs = DEBUG_MAX_LOGS;

% Run the summary builder for the current folder.
process_summary(rootDir, outDir, maxLogs);

function process_summary(rootDir, outDir, maxLogs)
%MAKE_LOG_SUMMARY  Build a summary report over all .bin logs in a folder tree.
%   Usage:
%       make_log_summary            % runs with current folder and config above
%       process_summary('c:\path\to\logs', 'c:\path\to\out', 3);
%
%   Reads only .bin files via Ardupilog and writes one Markdown report:
%     - summary_report.md
%
%   This script intentionally avoids CSV or external parsers and relies only
%   on Ardupilog for the raw binary logs.

    global DEBUG_MAX_LOGS MIN_DURATION_SEC MIN_SPEED_MPS MIN_THROTTLE_OUT

    if nargin < 1 || isempty(rootDir)
        rootDir = pwd;
    end
    if nargin < 2 || isempty(outDir)
        outDir = rootDir;
    end
    if nargin < 3 || isempty(maxLogs)
        maxLogs = DEBUG_MAX_LOGS;
    end

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    binFiles = find_bin_files(rootDir);
    if isempty(binFiles)
        error('No .bin files found under %s', rootDir);
    end

    if isfinite(maxLogs) && maxLogs > 0 && numel(binFiles) > maxLogs
        binFiles = binFiles(1:maxLogs);
        fprintf('Debug mode: processing only first %d log(s).\n', maxLogs);
    end

    processedLogs = {};
    paramMaps = {};

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
        paramMaps{end + 1} = struct('FileName', rec.FileName, 'Map', extract_last_param_map(log));
    end

    if isempty(processedLogs)
        error('No logs were successfully read with Ardupilog in %s', rootDir);
    end

    [processedLogs, paramMaps] = filter_meaningful_logs(processedLogs, paramMaps, MIN_DURATION_SEC, MIN_SPEED_MPS, MIN_THROTTLE_OUT);
    if isempty(processedLogs)
        error('No meaningful logs remained after filtering short / inactive runs in %s', rootDir);
    end

    summaryTable = struct2table([processedLogs{:}]);
    summaryTable = sortrows(summaryTable, 'FileName');

    paramTable = build_changed_param_table(paramMaps);
    write_summary_markdown(summaryTable, paramTable, outDir);

    fprintf('\nSummary report written to:\n');
    fprintf('  %s\n', fullfile(outDir, 'summary_report.md'));
end

function fileList = find_bin_files(rootDir)
    fileList = {};
    allFiles = dir(rootDir);
    for i = 1:numel(allFiles)
        if allFiles(i).isdir && ~strcmp(allFiles(i).name, '.') && ~strcmp(allFiles(i).name, '..')
            subFiles = find_bin_files(fullfile(rootDir, allFiles(i).name));
            fileList = [fileList, subFiles];
        end
    end

    allBin = dir(fullfile(rootDir, '*.bin'));
    for i = 1:numel(allBin)
        fileList{end + 1} = fullfile(rootDir, allBin(i).name);
    end
end

function rec = summarize_single_log(log, fullPath)
    rec = struct();
    rec.FileName = basename_from_path(fullPath);
    rec.FilePath = fullPath;
    rec.LogDir = fileparts(fullPath);

    bootTimeVal = get_field_value(log, 'bootTimeUTC');
    if ~isempty(bootTimeVal)
        rec.BootTimeUTC = char(string(bootTimeVal));
    else
        rec.BootTimeUTC = '';
    end

    rec.DurationSec = compute_duration(log);
    rec.MainMode = 'UNKNOWN';
    rec.ModeSummary = '';
    rec.AvgSpeedMps = NaN;
    rec.MaxSpeedMps = NaN;
    rec.MaxTurnRateRaw = NaN;
    rec.ParamCount = 0;

    modeInfo = summarize_modes(log);
    if ~isempty(modeInfo)
        rec.MainMode = modeInfo.mainMode;
        rec.ModeSummary = modeInfo.summaryText;
    end

    [avgSpeed, maxSpeed] = summarize_speed(log);
    rec.AvgSpeedMps = avgSpeed;
    rec.MaxSpeedMps = maxSpeed;
    rec.MaxTurnRateRaw = summarize_turn_rate(log);

    paramMap = extract_last_param_map(log);
    rec.ParamCount = numel(keys(paramMap));
end

function [filteredLogs, filteredParamMaps] = filter_meaningful_logs(processedLogs, paramMaps, minDurationSec, minSpeedMps, minThrottleOut)
    filteredLogs = {};
    filteredParamMaps = {};

    for i = 1:numel(processedLogs)
        rec = processedLogs{i};
        if is_meaningful_log(rec, minDurationSec, minSpeedMps, minThrottleOut)
            filteredLogs{end + 1} = rec;
            filteredParamMaps{end + 1} = paramMaps{i};
        end
    end
end

function keep = is_meaningful_log(rec, minDurationSec, minSpeedMps, minThrottleOut)
    global MIN_DURATION_SEC MIN_SPEED_MPS MIN_THROTTLE_OUT
    keep = false;

    if isempty(rec)
        return;
    end

    if nargin < 2 || isempty(minDurationSec)
        minDurationSec = MIN_DURATION_SEC;
    end
    if nargin < 3 || isempty(minSpeedMps)
        minSpeedMps = MIN_SPEED_MPS;
    end
    if nargin < 4 || isempty(minThrottleOut)
        minThrottleOut = MIN_THROTTLE_OUT;
    end

    durationSec = rec.DurationSec;
    maxSpeed = rec.MaxSpeedMps;
    maxThrottleOut = summarize_max_throttle_out_from_rec(rec);

    if ~isnumeric(durationSec) || isnan(durationSec)
        durationSec = 0;
    end
    if ~isnumeric(maxSpeed) || isnan(maxSpeed)
        maxSpeed = 0;
    end
    if ~isnumeric(maxThrottleOut) || isnan(maxThrottleOut)
        maxThrottleOut = 0;
    end

    if durationSec < minDurationSec
        keep = (maxSpeed >= (minSpeedMps + 0.2)) && (maxThrottleOut >= (minThrottleOut + 0.05));
    else
        keep = (maxSpeed >= minSpeedMps) && (maxThrottleOut >= minThrottleOut);
    end
end

function maxThrottle = summarize_max_throttle_out_from_rec(rec)
    maxThrottle = NaN;
    if isempty(rec) || ~isfield(rec, 'FileName')
        return;
    end

    fullPath = rec.FilePath;
    if isempty(fullPath) || ~exist(fullPath, 'file')
        return;
    end

    try
        log = Ardupilog(fullPath);
        if ismethod(log, 'deleteEmptyMsgs')
            log = log.deleteEmptyMsgs;
        end
    catch
        return;
    end

    thrObj = get_field_value(log, 'THR');
    if isempty(thrObj)
        return;
    end

    throttleOut = get_field_value(thrObj, 'ThrOut');
    if isempty(throttleOut)
        throttleOut = get_field_value(thrObj, 'ThrottleOut');
    end
    if isempty(throttleOut)
        return;
    end

    vals = double(throttleOut(:));
    vals = vals(~isnan(vals) & isfinite(vals));
    if isempty(vals)
        return;
    end

    maxThrottle = max(abs(vals));
end

function durationSec = compute_duration(log)
    timeVec = [];

    modeObj = get_field_value(log, 'MODE');
    if ~isempty(modeObj)
        vals = get_field_value(modeObj, 'TimeS');
        if ~isempty(vals)
            timeVec = [timeVec; double(vals(:))];
        end
    end

    gpsObj = get_field_value(log, 'GPS');
    if ~isempty(gpsObj)
        vals = get_field_value(gpsObj, 'TimeS');
        if ~isempty(vals)
            timeVec = [timeVec; double(vals(:))];
        end
    end

    sterObj = get_field_value(log, 'STER');
    if ~isempty(sterObj)
        vals = get_field_value(sterObj, 'TimeS');
        if ~isempty(vals)
            timeVec = [timeVec; double(vals(:))];
        end
    end

    thrObj = get_field_value(log, 'THR');
    if ~isempty(thrObj)
        vals = get_field_value(thrObj, 'TimeS');
        if ~isempty(vals)
            timeVec = [timeVec; double(vals(:))];
        end
    end

    if isempty(timeVec)
        durationSec = 0;
        return;
    end

    timeVec = double(timeVec(~isnan(timeVec) & isfinite(timeVec)));
    if isempty(timeVec)
        durationSec = 0;
        return;
    end

    durationSec = max(timeVec) - min(timeVec);
    if ~isfinite(durationSec) || durationSec < 0
        durationSec = 0;
    end
    if durationSec == 0 && ~isempty(timeVec)
        durationSec = max(timeVec) - min(timeVec);
    end
end

function modeInfo = summarize_modes(log)
    modeInfo = [];
    modeObj = get_field_value(log, 'MODE');
    if isempty(modeObj)
        return;
    end

    tRaw = get_field_value(modeObj, 'TimeS');
    mRaw = get_field_value(modeObj, 'Mode');
    if isempty(tRaw) || isempty(mRaw)
        return;
    end

    t = double(tRaw(:));
    m = double(mRaw(:));
    if isempty(t) || isempty(m) || numel(t) ~= numel(m)
        return;
    end

    [t, ord] = sort(t);
    m = m(ord);
    accum = containers.Map('KeyType', 'char', 'ValueType', 'double');
    sessionEnd = compute_log_end_time(log);
    if isempty(sessionEnd)
        sessionEnd = t(end);
    end

    startMode = m(1);
    startTime = t(1);

    for k = 2:numel(m)
        if m(k) ~= startMode
            key = mode_name_from_id(startMode);
            duration = t(k) - startTime;
            if duration < 0
                duration = 0;
            end
            if isKey(accum, key)
                accum(key) = accum(key) + duration;
            else
                accum(key) = duration;
            end
            startMode = m(k);
            startTime = t(k);
        end
    end

    key = mode_name_from_id(startMode);
    duration = sessionEnd - startTime;
    if duration < 0
        duration = 0;
    end
    if isKey(accum, key)
        accum(key) = accum(key) + duration;
    else
        accum(key) = duration;
    end

    keysList = keys(accum);
    valuesList = values(accum);
    durations = cell2mat(valuesList);

    keepMask = durations >= 5.0;
    keysList = keysList(keepMask);
    valuesList = valuesList(keepMask);
    durations = cell2mat(valuesList);

    if isempty(durations)
        modeInfo = [];
        return;
    end

    [sortedDur, ord2] = sort(durations, 'descend');

    summaryParts = {};
    for j = 1:numel(ord2)
        name = char(keysList(ord2(j)));
        summaryParts{end + 1} = sprintf('%s: %.1fs', name, sortedDur(j));
    end

    if isempty(summaryParts)
        return;
    end

    modeInfo.summaryText = strjoin(summaryParts, ', ');
    modeInfo.mainMode = char(keysList(ord2(1)));
end

function endTime = compute_log_end_time(log)
    allTimes = [];

    candidates = {'MODE', 'GPS', 'STER', 'THR'};
    for c = 1:numel(candidates)
        obj = get_field_value(log, candidates{c});
        if ~isempty(obj)
            vals = get_field_value(obj, 'TimeS');
            if ~isempty(vals)
                allTimes = [allTimes; double(vals(:))];
            end
        end
    end

    if isempty(allTimes)
        endTime = [];
        return;
    end

    allTimes = allTimes(~isnan(allTimes) & isfinite(allTimes));
    if isempty(allTimes)
        endTime = [];
        return;
    end

    endTime = max(allTimes);
end

function name = mode_name_from_id(modeId)
    modeMap = {
        'MANUAL'; 'ACRO'; 'STEERING'; 'HOLD'; 'LOITER'; 'FOLLOW'; ...
        'SIMPLE'; 'DOCK'; 'CIRCLE'; 'AUTO'; 'RTL'; 'SMART_RTL'; ...
        'GUIDED'; 'INITIALISING'
    };

    idx = modeId + 1;
    if idx >= 1 && idx <= numel(modeMap)
        name = modeMap{idx};
    else
        name = sprintf('MODE_%d', modeId);
    end
end

function [avgSpeed, maxSpeed] = summarize_speed(log)
    avgSpeed = NaN;
    maxSpeed = NaN;

    candidates = {};
    gpsObj = get_field_value(log, 'GPS');
    if ~isempty(gpsObj)
        gpsSpd = get_field_value(gpsObj, 'Spd');
        if ~isempty(gpsSpd)
            vals = double(gpsSpd);
            candidates{end + 1} = vals(:);
        end
    end
    thrObj = get_field_value(log, 'THR');
    if ~isempty(thrObj)
        thrSpeed = get_field_value(thrObj, 'Speed');
        if ~isempty(thrSpeed)
            vals = double(thrSpeed);
            candidates{end + 1} = vals(:);
        end
    end

    for i = 1:numel(candidates)
        vals = candidates{i};
        vals = vals(~isnan(vals) & isfinite(vals));
        if isempty(vals)
            continue;
        end
        avgSpeed = mean(vals);
        maxSpeed = max(vals);
        return;
    end
end

function maxTurnRate = summarize_turn_rate(log)
    maxTurnRate = NaN;
    sterObj = get_field_value(log, 'STER');
    turnRate = get_field_value(sterObj, 'TurnRate');
    if isempty(turnRate)
        return;
    end

    vals = double(turnRate);
    vals = vals(:);
    vals = vals(~isnan(vals) & isfinite(vals));
    if isempty(vals)
        return;
    end
    maxTurnRate = max(abs(vals));
end

function paramMap = extract_last_param_map(log)
    paramMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    P = get_field_value(log, 'PARM');
    if isempty(P)
        return;
    end
    if istable(P)
        if ~ismember('Name', P.Properties.VariableNames) || ~ismember('Value', P.Properties.VariableNames)
            return;
        end
        names = P.Name(:);
        values = P.Value(:);
        for k = 1:numel(names)
            key = char(string(names{k}));
            if ~isempty(key)
                paramMap(key) = values(k);
            end
        end
        return;
    end

    if isstruct(P)
        if isfield(P, 'Name') && isfield(P, 'Value')
            names = P.Name(:);
            values = P.Value(:);
            for k = 1:numel(names)
                key = char(string(names{k}));
                if ~isempty(key)
                    paramMap(key) = values(k);
                end
            end
            return;
        end

        % Some builds expose params as a struct of names to values.
        fn = fieldnames(P);
        for k = 1:numel(fn)
            key = fn{k};
            val = P.(key);
            if ~isempty(val)
                paramMap(char(key)) = val;
            end
        end
    end
end

function paramTable = build_changed_param_table(paramMaps)
    paramTable = table();
    if isempty(paramMaps)
        return;
    end

    allNames = {};
    for i = 1:numel(paramMaps)
        if isempty(paramMaps{i}.Map)
            continue;
        end
        ks = keys(paramMaps{i}.Map);
        allNames = [allNames, ks];
    end
    allNames = unique(allNames);

    rows = {};
    for j = 1:numel(allNames)
        paramName = char(allNames{j});
        valueSummary = {};
        for i = 1:numel(paramMaps)
            if ~isempty(paramMaps{i}.Map) && isKey(paramMaps{i}.Map, paramName)
                val = paramMaps{i}.Map(paramName);
                valueSummary{end + 1} = sprintf('%s=%s', paramMaps{i}.FileName, value_to_string(val));
            end
        end

        if numel(valueSummary) < 2
            continue;
        end

        uniqueVals = {};
        for k = 1:numel(valueSummary)
            uniqueVals{end + 1} = valueSummary{k};
        end
        if numel(unique(uniqueVals)) > 1
            rows{end + 1} = struct('ParamName', paramName, ...
                'ValueSummary', strjoin(valueSummary, '; '));
        end
    end

    if isempty(rows)
        return;
    end

    paramTable = struct2table([rows{:}]);
end

function s = value_to_string(val)
    if ischar(val)
        s = val;
        return;
    end

    if iscell(val)
        s = strjoin(cellfun(@(x) value_to_string(x), val, 'UniformOutput', false), ', ');
        return;
    end

    if isnumeric(val) || islogical(val)
        if numel(val) == 1
            s = num2str(val);
        else
            s = sprintf('%s', mat2str(val));
        end
        return;
    end

    s = char(string(val));
end

function write_summary_markdown(summaryTable, paramTable, outDir)
    reportPath = fullfile(outDir, 'summary_report.md');
    fid = fopen(reportPath, 'w');
    if fid == -1
        error('Could not create summary report file %s', reportPath);
    end

    fprintf(fid, '# Log summary report\n\n');
    fprintf(fid, 'Generated for %d log(s).\n\n', height(summaryTable));

    fprintf(fid, '## Overview\n\n');
    fprintf(fid, '| File | Boot time UTC | Duration (s) | Main mode | Mode summary | Avg speed (m/s) | Max speed (m/s) | Max turn rate | Params |\n');
    fprintf(fid, '| --- | --- | ---: | --- | --- | ---: | ---: | ---: | ---: |\n');

    for i = 1:height(summaryTable)
        row = summaryTable(i, :);
        fileName = safe_markdown_cell(row.FileName);
        bootTime = safe_markdown_cell(row.BootTimeUTC);
        modeName = safe_markdown_cell(row.MainMode);
        modeSummary = safe_markdown_cell(row.ModeSummary);
        durationVal = format_numeric_markdown(row.DurationSec);
        avgVal = format_numeric_markdown(row.AvgSpeedMps);
        maxVal = format_numeric_markdown(row.MaxSpeedMps);
        turnVal = format_numeric_markdown(row.MaxTurnRateRaw);
        paramCount = sprintf('%d', row.ParamCount);

        fprintf(fid, '| %s | %s | %s | %s | %s | %s | %s | %s | %s |\n', ...
            fileName, bootTime, durationVal, modeName, modeSummary, avgVal, maxVal, turnVal, paramCount);
    end

    fprintf(fid, '\n## Changed parameters\n\n');
    if isempty(paramTable)
        fprintf(fid, 'No changed parameters detected.\n');
    else
        fprintf(fid, '| Parameter | Value summary |\n');
        fprintf(fid, '| --- | --- |\n');

        for i = 1:height(paramTable)
            row = paramTable(i, :);
            nameCell = safe_markdown_cell(row.ParamName);
            valueCell = safe_markdown_cell(row.ValueSummary);
            fprintf(fid, '| %s | %s |\n', nameCell, valueCell);
        end
    end

    fclose(fid);
end

function s = safe_markdown_cell(value)
    if isempty(value)
        s = '-';
        return;
    end

    if iscell(value)
        s = strjoin(cellfun(@(x) safe_markdown_cell(x), value, 'UniformOutput', false), '; ');
        return;
    end

    if isnumeric(value) || islogical(value)
        s = format_numeric_markdown(value);
        return;
    end

    s = char(string(value));
    s = strrep(s, '\n', ' ');
    s = strrep(s, '|', '\\|');
end

function s = format_numeric_markdown(value)
    if isempty(value)
        s = '-';
        return;
    end

    if isnumeric(value) || islogical(value)
        if numel(value) ~= 1 || isnan(value)
            s = 'N/A';
            return;
        end
        s = num2str(value);
        return;
    end

    s = safe_markdown_cell(value);
end

function tf = has_field_value(obj, fieldName)
    if isstruct(obj)
        tf = isfield(obj, fieldName);
    elseif isobject(obj)
        tf = isprop(obj, fieldName);
    else
        tf = false;
    end
end

function val = get_field_value(obj, fieldName)
    if isempty(obj)
        val = [];
        return;
    end

    if isstruct(obj)
        if isfield(obj, fieldName)
            val = obj.(fieldName);
        else
            val = [];
        end
        return;
    end

    if isobject(obj)
        if isprop(obj, fieldName)
            val = obj.(fieldName);
        else
            val = [];
        end
        return;
    end

    val = [];
end

function base = basename_from_path(p)
    [~, name, ext] = fileparts(p);
    base = [name ext];
end

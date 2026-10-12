function summaryTable = filter_summary_segments(summaryTable, minDurationSec, minSpeedMps)
    if isempty(summaryTable) || height(summaryTable) == 0
        return;
    end

    if nargin < 2 || isempty(minDurationSec)
        minDurationSec = 20;
    end
    if nargin < 3 || isempty(minSpeedMps)
        minSpeedMps = 1;
    end

    keep = true(height(summaryTable), 1);
    for i = 1:height(summaryTable)
        if iscell(summaryTable.ModeSummary)
            modeSummaryValue = summaryTable.ModeSummary{i};
        else
            modeSummaryValue = summaryTable.ModeSummary(i);
        end
        [filteredSummary, filteredMainMode] = filter_mode_summary(modeSummaryValue, minDurationSec);
        if iscell(summaryTable.ModeSummary)
            summaryTable.ModeSummary{i} = filteredSummary;
            summaryTable.MainMode{i} = filteredMainMode;
        else
            summaryTable.ModeSummary(i) = string(filteredSummary);
            summaryTable.MainMode(i) = string(filteredMainMode);
        end

        changedParams = summaryTable.ChangedParams(i);
        hasParamChange = ~isempty(changedParams) && ~all(ismissing(string(changedParams))) && ...
            strlength(strtrim(string(changedParams))) > 0;

        durationSec = double(summaryTable.DurationSec(i));
        maxSpeed = double(summaryTable.MaxSpeedMps(i));
        if ~isfinite(durationSec)
            durationSec = 0;
        end
        if ~isfinite(maxSpeed)
            maxSpeed = 0;
        end

        isShort = durationSec < minDurationSec;
        isStationary = maxSpeed < minSpeedMps;
        if ~hasParamChange && (isShort || isStationary)
            keep(i) = false;
        end
    end

    summaryTable = summaryTable(keep, :);
end

function [filteredSummary, mainMode] = filter_mode_summary(summaryValue, minDurationSec)
    filteredSummary = '';
    mainMode = 'UNKNOWN';
    if isempty(summaryValue) || all(ismissing(string(summaryValue))) || strlength(strtrim(string(summaryValue))) == 0
        return;
    end

    parts = regexp(char(string(summaryValue)), '<br>|, ', 'split');
    names = {};
    durations = [];
    for i = 1:numel(parts)
        part = strtrim(parts{i});
        delimiter = strfind(part, ':');
        if isempty(delimiter)
            continue;
        end

        name = strtrim(part(1:delimiter(1) - 1));
        durationText = strrep(strtrim(part(delimiter(1) + 1:end)), 's', '');
        duration = str2double(durationText);
        if isempty(name) || ~isfinite(duration) || duration < minDurationSec
            continue;
        end

        names{end + 1} = name;
        durations(end + 1) = duration;
    end

    if isempty(names)
        return;
    end

    summaryParts = cell(1, numel(names));
    for i = 1:numel(names)
        summaryParts{i} = sprintf('%s: %.1fs', names{i}, durations(i));
    end
    filteredSummary = strjoin(summaryParts, '<br>');

    priorityModes = {'AUTO', 'RTL', 'ACRO'};
    mainMode = names{1};
    for i = 1:numel(priorityModes)
        priorityIndex = find(strcmp(names, priorityModes{i}), 1);
        if ~isempty(priorityIndex)
            mainMode = priorityModes{i};
            return;
        end
    end

    [~, longestIndex] = max(durations);
    mainMode = names{longestIndex};
end
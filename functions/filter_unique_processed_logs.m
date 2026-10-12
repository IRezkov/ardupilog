function [uniqueLogs, uniqueParamMaps] = filter_unique_processed_logs(processedLogs, paramMaps)
    uniqueLogs = {};
    uniqueParamMaps = {};

    if isempty(processedLogs)
        return;
    end

    seenKeys = {};
    for i = 1:numel(processedLogs)
        rec = processedLogs{i};
        key = '';

        if isstruct(rec)
            if isfield(rec, 'FilePath') && ~isempty(rec.FilePath)
                key = lower(strtrim(rec.FilePath));
            elseif isfield(rec, 'FileName') && ~isempty(rec.FileName)
                key = lower(strtrim(rec.FileName));
            end
        end

        if isempty(key)
            if i <= numel(paramMaps) && isstruct(paramMaps{i}) && isfield(paramMaps{i}, 'FileName') && ~isempty(paramMaps{i}.FileName)
                key = lower(strtrim(paramMaps{i}.FileName));
            end
        end

        if isempty(key)
            key = sprintf('index_%d', i);
        end

        alreadySeen = false;
        for j = 1:numel(seenKeys)
            if strcmpi(seenKeys{j}, key)
                alreadySeen = true;
                break;
            end
        end

        if ~alreadySeen
            uniqueLogs{end + 1} = rec;
            if i <= numel(paramMaps)
                uniqueParamMaps{end + 1} = paramMaps{i};
            else
                uniqueParamMaps{end + 1} = [];
            end
            seenKeys{end + 1} = key;
        end
    end
end

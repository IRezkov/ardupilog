function [filteredLogs, filteredParamMaps, keepMask] = filter_meaningful_logs(processedLogs, paramMaps, minDurationSec, minSpeedMps, minThrottleOut)
    filteredLogs = {};
    filteredParamMaps = {};
    keepMask = false(1, numel(processedLogs));

    for i = 1:numel(processedLogs)
        rec = processedLogs{i};
        if is_meaningful_log(rec, minDurationSec, minSpeedMps, minThrottleOut)
            filteredLogs{end + 1} = rec;
            filteredParamMaps{end + 1} = paramMaps{i};
            keepMask(i) = true;
        end
    end
end

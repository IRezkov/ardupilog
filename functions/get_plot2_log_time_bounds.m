function [startTime, endTime] = get_plot2_log_time_bounds(logObj)
%GET_PLOT2_LOG_TIME_BOUNDS Get the finite TimeS range across log messages.

startTime = Inf;
endTime = -Inf;
if isempty(logObj) || ~isobject(logObj)
    startTime = 0;
    endTime = 0;
    return;
end

groupNames = properties(logObj);
for groupIndex = 1:numel(groupNames)
    message = logObj.(groupNames{groupIndex});
    if isempty(message) || ~isobject(message) || ~isprop(message, 'TimeS')
        continue;
    end

    timeValues = message.TimeS;
    if ~isnumeric(timeValues) || isempty(timeValues)
        continue;
    end
    finiteTimes = double(timeValues(isfinite(timeValues)));
    if isempty(finiteTimes)
        continue;
    end

    startTime = min(startTime, min(finiteTimes));
    endTime = max(endTime, max(finiteTimes));
end

reliableEndTime = compute_log_end_time(logObj);
if ~isempty(reliableEndTime) && isfinite(reliableEndTime)
    endTime = reliableEndTime;
end

if ~isfinite(startTime) || ~isfinite(endTime)
    startTime = 0;
    endTime = 0;
end
end
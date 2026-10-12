function signal = read_plot2_actuator_signal(logObj, groupName, fieldNames, t0)
signal = struct('time', [], 'values', []);
if ~isprop(logObj, groupName)
    return;
end

message = logObj.(groupName);
if isempty(message) || ~isprop(message, 'TimeS')
    return;
end

fieldName = '';
for fieldIndex = 1:numel(fieldNames)
    if isprop(message, fieldNames{fieldIndex})
        fieldName = fieldNames{fieldIndex};
        break;
    end
end
if isempty(fieldName)
    return;
end

time = double(message.TimeS(:)) - t0;
values = double(message.(fieldName)(:));
sampleCount = min(numel(time), numel(values));
time = time(1:sampleCount);
values = values(1:sampleCount);
valid = isfinite(time) & isfinite(values);
time = time(valid);
values = values(valid);
if isempty(time)
    return;
end

[time, order] = sort(time);
values = values(order);
[signal.time, uniqueIndex] = unique(time, 'stable');
signal.values = values(uniqueIndex);
end

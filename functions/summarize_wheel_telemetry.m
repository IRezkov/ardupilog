function info = summarize_wheel_telemetry(log)
%SUMMARIZE_WHEEL_TELEMETRY Count wheels from unique WTLM telemetry IDs.

info = struct( ...
    'WheelCount', NaN, ...
    'WheelDistanceM', NaN, ...
    'WheelIds', 'Unknown (WTLM telemetry unavailable)');

if isstruct(log)
    logProperties = fieldnames(log);
elseif isobject(log)
    logProperties = properties(log);
else
    logProperties = {};
end

wheelGroups = logProperties(cellfun(@(name) ...
    ~isempty(regexp(name, '^WTLM\d*$', 'once')), logProperties));
wheelIds = [];
wheelDistances = [];
for groupIndex = 1:numel(wheelGroups)
    wheelLog = get_field_value(log, wheelGroups{groupIndex});
    ids = get_field_value(wheelLog, 'id');
    if isempty(ids)
        ids = get_field_value(wheelLog, 'ID');
    end
    if isnumeric(ids)
        ids = double(ids(:));
        wheelIds = [wheelIds; ids];
        distances = get_field_value(wheelLog, 'Dist');
        if isnumeric(distances) && numel(distances) == numel(ids)
            distances = double(distances(:));
            validDistance = isfinite(ids) & isfinite(distances);
            groupWheelIds = unique(ids(validDistance));
            for wheelIndex = 1:numel(groupWheelIds)
                wheelValues = distances(validDistance & ids == groupWheelIds(wheelIndex));
                if numel(wheelValues) >= 2
                    wheelDistances(end + 1) = max(wheelValues) - min(wheelValues);
                end
            end
        end
    end

end

wheelIds = unique(wheelIds(isfinite(wheelIds)));
if ~isempty(wheelIds)
    info.WheelCount = numel(wheelIds);
    idTexts = arrayfun(@(id) sprintf('%g', id), wheelIds, 'UniformOutput', false);
    info.WheelIds = strjoin(idTexts, ', ');
end
if ~isempty(wheelDistances)
    info.WheelDistanceM = max(wheelDistances);
end
end

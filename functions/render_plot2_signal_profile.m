function [lineHandles, unavailableIds] = render_plot2_signal_profile( ...
    axesHandle, logObj, catalog, signalIds, t0, targetTrajectory)
%RENDER_PLOT2_SIGNAL_PROFILE Draw selected raw and derived log signals.

lineHandles = gobjects(0);
unavailableIds = {};
if isstring(signalIds)
    signalIds = cellstr(signalIds(:));
end

for signalIndex = 1:numel(signalIds)
    signalId = char(signalIds{signalIndex});
    catalogIndex = find(strcmp({catalog.id}, signalId), 1);
    if isempty(catalogIndex)
        unavailableIds{end + 1} = signalId; %#ok<AGROW>
        continue;
    end

    entry = catalog(catalogIndex);
    [timeValues, signalValues, isAvailable] = get_signal_values( ...
        logObj, entry, targetTrajectory);
    if ~isAvailable || numel(timeValues) ~= numel(signalValues) || isempty(timeValues)
        unavailableIds{end + 1} = signalId; %#ok<AGROW>
        continue;
    end
    if strcmp(signalId, 'SUTS.LPos')
        signalValues = -double(signalValues);
    end

    lineArgs = {'DisplayName', entry.label};
    if strcmp(entry.kind, 'target_error_north')
        lineArgs = [lineArgs, {'Color', [0.1 0.1 0.1], 'LineWidth', 1.2}]; %#ok<AGROW>
    elseif strcmp(entry.kind, 'target_error_east')
        lineArgs = [lineArgs, {'Color', [0.1 0.3 0.9], 'LineWidth', 1.2}]; %#ok<AGROW>
    elseif strcmp(entry.kind, 'target_error')
        lineArgs = [lineArgs, {'Color', [0.7 0 0.7], 'LineWidth', 1.7}]; %#ok<AGROW>
    end

    xValues = double(timeValues(:));
    if ~startsWith(entry.kind, 'target_error')
        xValues = xValues - t0;
    end
    lineHandles(end + 1) = plot(axesHandle, xValues, ...
        double(signalValues(:)), lineArgs{:}); %#ok<AGROW>
end
end

function [timeValues, signalValues, isAvailable] = get_signal_values( ...
    logObj, entry, targetTrajectory)
timeValues = [];
signalValues = [];
isAvailable = false;

if startsWith(entry.kind, 'target_error')
    if ~isstruct(targetTrajectory) || ~isfield(targetTrajectory, 'time') || ...
            isempty(targetTrajectory.time)
        return;
    end
    timeValues = targetTrajectory.time;
    switch entry.kind
        case 'target_error_north'
            signalValues = targetTrajectory.targetNorth - targetTrajectory.actualNorth;
        case 'target_error_east'
            signalValues = targetTrajectory.targetEast - targetTrajectory.actualEast;
        case 'target_error'
            signalValues = targetTrajectory.errorM;
    end
    isAvailable = true;
    return;
end

message = get_log_message(logObj, entry.group);
if isempty(message)
    return;
end
timeValues = get_message_field(message, 'TimeS');
if isempty(timeValues)
    return;
end

switch entry.kind
    case 'raw'
        signalValues = get_message_field(message, entry.field);
    case {'speed_kmh', 'des_speed_kmh', 'thr_out_filtered'}
        sourceField = entry.field;
        sourceValues = get_message_field(message, sourceField);
        if isempty(sourceValues) || numel(sourceValues) ~= numel(timeValues)
            return;
        end
        keep = find_time_outliers(message, [], false);
        timeValues = timeValues(keep);
        signalValues = sourceValues(keep);
        if strcmp(entry.kind, 'speed_kmh') || strcmp(entry.kind, 'des_speed_kmh')
            signalValues = signalValues * 3.6;
        end
    case 'steer_out_scaled'
        signalValues = get_message_field(message, entry.field) ./ 450;
    case {'rpm_left_scaled', 'rpm_right_scaled'}
        rpm = get_message_field(message, 'RPM');
        gas = get_message_field(message, 'Gas');
        direction = get_message_field(message, 'Dir');
        if isempty(rpm) || isempty(gas) || isempty(direction) || ...
                numel(rpm) ~= numel(timeValues) || ...
                numel(gas) ~= numel(timeValues) || ...
                numel(direction) ~= numel(timeValues)
            return;
        end
        maxRpm = max(double(rpm), [], 'omitnan');
        maxGas = max(double(gas), [], 'omitnan');
        if ~isfinite(maxRpm) || maxRpm == 0 || ~isfinite(maxGas)
            return;
        end
        direction(direction == 1) = -1;
        direction(direction == 0) = 1;
        signalValues = double(rpm) ./ maxRpm .* maxGas .* double(direction);
    otherwise
        return;
end

isAvailable = ~isempty(signalValues) && numel(signalValues) == numel(timeValues);
end

function message = get_log_message(logObj, groupName)
message = [];
if isobject(logObj) && isprop(logObj, groupName)
    message = logObj.(groupName);
elseif isstruct(logObj) && isfield(logObj, groupName)
    message = logObj.(groupName);
end
end

function value = get_message_field(message, fieldName)
value = [];
if isobject(message) && isprop(message, fieldName)
    value = message.(fieldName);
elseif isstruct(message) && isfield(message, fieldName)
    value = message.(fieldName);
elseif istable(message) && ismember(fieldName, message.Properties.VariableNames)
    value = message.(fieldName);
end
end
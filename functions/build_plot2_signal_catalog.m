function catalog = build_plot2_signal_catalog(logObj, targetTrajectory)
%BUILD_PLOT2_SIGNAL_CATALOG List plottable numeric fields in an Ardupilog log.
% Raw entries identify message fields aligned with TimeS. Derived entries
% describe signals computed from one or more message fields.

if nargin < 2
    targetTrajectory = [];
end

catalog = struct('id', {}, 'group', {}, 'messageGroup', {}, ...
    'field', {}, 'kind', {}, 'label', {}, 'wheelId', {});
if isempty(logObj) || ~(isobject(logObj) || isstruct(logObj))
    return;
end

excludedFields = {'TimeS', 'TimeUS', 'DatenumUTC', 'LineNo', ...
    'MsgInstance', 'typeNumID', 'fieldUnits', 'fieldMultipliers', 'name'};
if isstruct(logObj)
    groupNames = fieldnames(logObj);
else
    groupNames = properties(logObj);
end

for groupIndex = 1:numel(groupNames)
    groupName = groupNames{groupIndex};
    message = logObj.(groupName);
    if isempty(message)
        continue;
    end

    if isobject(message)
        if ~isprop(message, 'TimeS')
            continue;
        end
        fieldNames = properties(message);
    elseif isstruct(message)
        if ~isfield(message, 'TimeS')
            continue;
        end
        fieldNames = fieldnames(message);
    elseif istable(message)
        fieldNames = message.Properties.VariableNames;
    else
        continue;
    end

    timeValues = read_message_field(message, 'TimeS');
    if ~isnumeric(timeValues) || ~isvector(timeValues) || isempty(timeValues)
        continue;
    end

    isWheelTelemetry = ~isempty(regexp(groupName, '^(WTLM|WIMU)\d*$', 'once'));
    wheelIdValues = [];
    if isWheelTelemetry
        wheelIdValues = read_message_field(message, 'id');
        if isempty(wheelIdValues)
            wheelIdValues = read_message_field(message, 'ID');
        end
        if ~(isnumeric(wheelIdValues) || islogical(wheelIdValues)) || ...
                numel(wheelIdValues) ~= numel(timeValues)
            wheelIdValues = [];
        else
            wheelIdValues = double(wheelIdValues(:));
        end
    end

    for fieldIndex = 1:numel(fieldNames)
        fieldName = fieldNames{fieldIndex};
        if ismember(fieldName, excludedFields) || ...
                (isWheelTelemetry && strcmpi(fieldName, 'id'))
            continue;
        end

        fieldValues = read_message_field(message, fieldName);
        if ~(isnumeric(fieldValues) || islogical(fieldValues)) || ...
                ~isvector(fieldValues) || numel(fieldValues) ~= numel(timeValues)
            continue;
        end

        catalog(end + 1) = make_entry( ...
            [groupName '.' fieldName], groupName, fieldName, 'raw', ...
            [groupName '.' fieldName]); %#ok<AGROW>

        if isWheelTelemetry && ~isempty(wheelIdValues)
            wheelIds = unique(wheelIdValues(isfinite(wheelIdValues)));
            for wheelIndex = 1:numel(wheelIds)
                wheelId = wheelIds(wheelIndex);
                wheelSignalId = sprintf('Wheel%g.%s.%s', ...
                    wheelId, groupName, fieldName);
                wheelGroup = sprintf('Wheel %g / %s', wheelId, groupName);
                wheelLabel = sprintf('Wheel %g %s.%s', ...
                    wheelId, groupName, fieldName);
                catalog(end + 1) = make_entry( ...
                    wheelSignalId, wheelGroup, fieldName, 'wheel_raw', ...
                    wheelLabel, wheelId, groupName); %#ok<AGROW>
            end
        end
    end

    isControllerImu = ~isempty(regexp(groupName, '^IMU\d*$', 'once'));
    isWheelImu = ~isempty(regexp(groupName, '^WIMU\d*$', 'once'));
    if isControllerImu || isWheelImu
        if isControllerImu
            accelerationFields = {'AccX', 'AccY', 'AccZ'};
        else
            accelerationFields = {'ax', 'ay', 'az'};
        end
        accelerationValues = cell(1, numel(accelerationFields));
        hasAccelerationData = true;
        for axisIndex = 1:numel(accelerationFields)
            accelerationValues{axisIndex} = read_message_field( ...
                message, accelerationFields{axisIndex});
            axisValues = accelerationValues{axisIndex};
            if ~(isnumeric(axisValues) || islogical(axisValues)) || ...
                    ~isvector(axisValues) || numel(axisValues) ~= numel(timeValues)
                hasAccelerationData = false;
                break;
            end
        end

        if hasAccelerationData && isControllerImu
            catalog(end + 1) = make_entry( ...
                ['Derived.' groupName '.AccelMagnitude'], groupName, ...
                'AccelMagnitude', 'imu_accel_magnitude', ...
                [groupName ' |a| (m/s^2)']); %#ok<AGROW>
            catalog(end + 1) = make_entry( ...
                ['Derived.' groupName '.LowAcceleration'], groupName, ...
                'LowAcceleration', 'imu_low_acceleration', ...
                [groupName ' low acceleration (<3 m/s^2)']); %#ok<AGROW>
        elseif hasAccelerationData && isWheelImu && ~isempty(wheelIdValues)
            wheelIds = unique(wheelIdValues(isfinite(wheelIdValues)));
            for wheelIndex = 1:numel(wheelIds)
                wheelId = wheelIds(wheelIndex);
                catalog(end + 1) = make_entry( ...
                    sprintf('Wheel%g.WIMU.AccelMagnitude', wheelId), ...
                    sprintf('Wheel %g / WIMU', wheelId), ...
                    'AccelMagnitude', 'imu_accel_magnitude', ...
                    sprintf('Wheel %g WIMU |a| (raw)', wheelId), ...
                    wheelId, groupName); %#ok<AGROW>
            end
        end
    end
end

if has_signal(catalog, 'THR.Speed')
    catalog(end + 1) = make_entry('Derived.SpeedKmh', 'THR', 'Speed', ...
        'speed_kmh', 'Speed (km/h)');
end
if has_signal(catalog, 'GPS.Spd')
    catalog(end + 1) = make_entry('Derived.GpsSpeedMs', 'GPS', 'Spd', ...
        'gps_speed_ms', 'GPS.Spd (m/s)');
    catalog(end + 1) = make_entry('Derived.GpsSpeedKmh', 'GPS', 'Spd', ...
        'gps_speed_kmh', 'GPS.Spd (km/h)');
end
if has_signal(catalog, 'THR.DesSpeed')
    catalog(end + 1) = make_entry('Derived.DesSpeedKmh', 'THR', 'DesSpeed', ...
        'des_speed_kmh', 'DesSpeed (km/h)');
end
if has_signal(catalog, 'THR.ThrOut')
    catalog(end + 1) = make_entry('Derived.ThrOutFiltered', 'THR', 'ThrOut', ...
        'thr_out_filtered', 'ThrOut (filtered)');
end
if has_signal(catalog, 'STER.SteerOut')
    catalog(end + 1) = make_entry('Derived.SteerOutScaled', 'STER', ...
        'SteerOut', 'steer_out_scaled', 'SteerOut (max=10)');
end
if has_signal(catalog, 'ANKL.RPM') && has_signal(catalog, 'ANKL.Gas') && ...
        has_signal(catalog, 'ANKL.Dir')
    catalog(end + 1) = make_entry('Derived.RPMLScaled', 'ANKL', ...
        'RPM', 'rpm_left_scaled', 'RPML /x');
end
if has_signal(catalog, 'ANKR.RPM') && has_signal(catalog, 'ANKR.Gas') && ...
        has_signal(catalog, 'ANKR.Dir')
    catalog(end + 1) = make_entry('Derived.RPMRScaled', 'ANKR', ...
        'RPM', 'rpm_right_scaled', 'RPMR /x');
end

if isstruct(targetTrajectory) && isfield(targetTrajectory, 'time') && ...
        ~isempty(targetTrajectory.time)
    derivedEntries = {
        'Derived.ErrorNorth', 'ErrorNorth', 'target_error_north', 'err North (PN)';
        'Derived.ErrorEast', 'ErrorEast', 'target_error_east', 'err East (PE)';
        'Derived.TargetError', 'TargetError', 'target_error', 'Target error (m)'};
    for entryIndex = 1:size(derivedEntries, 1)
        catalog(end + 1) = make_entry(derivedEntries{entryIndex, 1}, ...
            'Derived', derivedEntries{entryIndex, 2}, ...
            derivedEntries{entryIndex, 3}, derivedEntries{entryIndex, 4}); %#ok<AGROW>
    end
end
end

function value = read_message_field(message, fieldName)
if istable(message)
    if ismember(fieldName, message.Properties.VariableNames)
        value = message.(fieldName);
    else
        value = [];
    end
elseif isstruct(message)
    if isfield(message, fieldName)
        value = message.(fieldName);
    else
        value = [];
    end
elseif isobject(message) && isprop(message, fieldName)
    value = message.(fieldName);
else
    value = [];
end
end

function entry = make_entry(id, group, field, kind, label, wheelId, messageGroup)
if nargin < 6
    wheelId = NaN;
end
if nargin < 7
    messageGroup = group;
end
entry = struct('id', id, 'group', group, 'messageGroup', messageGroup, ...
    'field', field, 'kind', kind, 'label', label, 'wheelId', wheelId);
end

function found = has_signal(catalog, signalId)
found = any(strcmp({catalog.id}, signalId));
end
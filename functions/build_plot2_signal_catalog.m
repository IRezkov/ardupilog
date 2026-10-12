function catalog = build_plot2_signal_catalog(logObj, targetTrajectory)
%BUILD_PLOT2_SIGNAL_CATALOG List plottable numeric fields in an Ardupilog log.
% Raw entries identify message fields aligned with TimeS. Derived entries
% describe signals computed from one or more message fields.

if nargin < 2
    targetTrajectory = [];
end

catalog = struct('id', {}, 'group', {}, 'field', {}, 'kind', {}, 'label', {});
if isempty(logObj) || ~isobject(logObj)
    return;
end

excludedFields = {'TimeS', 'TimeUS', 'DatenumUTC', 'LineNo', ...
    'MsgInstance', 'typeNumID', 'fieldUnits', 'fieldMultipliers', 'name'};
groupNames = properties(logObj);

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

    for fieldIndex = 1:numel(fieldNames)
        fieldName = fieldNames{fieldIndex};
        if ismember(fieldName, excludedFields)
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
    end
end

if has_signal(catalog, 'THR.Speed')
    catalog(end + 1) = make_entry('Derived.SpeedKmh', 'THR', 'Speed', ...
        'speed_kmh', 'Speed (km/h)');
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

function entry = make_entry(id, group, field, kind, label)
entry = struct('id', id, 'group', group, 'field', field, ...
    'kind', kind, 'label', label);
end

function found = has_signal(catalog, signalId)
found = any(strcmp({catalog.id}, signalId));
end
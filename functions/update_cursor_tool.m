function update_cursor_tool(signalFigure, requestedTime)
    if isempty(signalFigure) || ~isvalid(signalFigure)
        return;
    end
    if ~isfield(signalFigure.UserData, 'cursorTool')
        return;
    end

    data = signalFigure.UserData.cursorTool;
    if ~data.enabled
        return;
    end
    if ~data.dragging && ~cursor_tool_can_interact(data.axes)
        deactivate_cursor_tool(signalFigure);
        return;
    end
    if nargin > 1 && isfinite(requestedTime)
        timeValue = requestedTime;
    else
        point = get(data.axes, 'CurrentPoint');
        timeValue = point(1, 1);
    end
    if ~isfinite(timeValue)
        return;
    end

    if isempty(data.cursorLine) || ~isvalid(data.cursorLine)
        data.cursorLine = xline(data.axes, timeValue, '--k', 'HandleVisibility', 'off');
    else
        data.cursorLine.Value = timeValue;
    end
    drawnow expose;

    lines = data.legend.UserData.Lines;
    baseNames = data.legend.UserData.BaseNames;
    currentClock = now * 86400;
    if currentClock - data.lastLegendUpdate >= 0.15
        legendStrings = baseNames;
        for i = 1:numel(lines)
            lineHandle = lines(i);
            if ~isvalid(lineHandle)
                continue;
            end
            [xData, yData] = get_cached_sorted_line_data(lineHandle);
            if numel(xData) < 2
                continue;
            end
            currentValue = interp1(xData, yData, timeValue, 'linear', NaN);
            if isfinite(currentValue)
                legendStrings{i} = sprintf('%s = %.3f', baseNames{i}, currentValue);
            end
        end
        data.legend.String = legendStrings;
        if isfield(data.legend.UserData, 'FixedAxesPosition')
            data.axes.Position = data.legend.UserData.FixedAxesPosition;
        end
        if isfield(data.legend.UserData, 'FixedPosition')
            data.legend.Position = data.legend.UserData.FixedPosition;
        end
        data.lastLegendUpdate = currentClock;
    end

    if is_target_active_at_time(signalFigure.UserData, timeValue) && ...
            isfield(signalFigure.UserData, 'targetTrajectory') && ...
            ~isempty(signalFigure.UserData.targetTrajectory.time)
        trajectory = signalFigure.UserData.targetTrajectory;
        targetNorth = interp1(trajectory.time, trajectory.targetNorth, timeValue, 'linear', NaN);
        targetEast = interp1(trajectory.time, trajectory.targetEast, timeValue, 'linear', NaN);

        [boatLat, boatLon, hasBoatPosition] = get_boat_position(signalFigure, timeValue);
        if hasBoatPosition
            actualNorth = (boatLat - trajectory.originLat) * trajectory.metersPerDegree;
            actualEast = (boatLon - trajectory.originLon) * ...
                trajectory.metersPerDegree * cosd(trajectory.originLat);
        else
            actualNorth = interp1(trajectory.time, trajectory.actualNorth, timeValue, 'linear', NaN);
            actualEast = interp1(trajectory.time, trajectory.actualEast, timeValue, 'linear', NaN);
        end
        if all(isfinite([actualNorth actualEast targetNorth targetEast]))
            update_boat_and_vector(signalFigure, trajectory, actualNorth, actualEast, targetNorth, targetEast, timeValue);
        end
    else
        hide_target_cursor_objects(signalFigure);
        update_ekf_or_gps_boat_marker(signalFigure, timeValue);
    end

    data.currentTime = timeValue;
    signalFigure.UserData.cursorTool = data;
end

function [xData, yData] = get_cached_sorted_line_data(lineHandle)
    % Sorting/deduping full line data on every mouse move is the main cause
    % of cursor lag on large logs, so cache the result on the line handle.
    cache = lineHandle.UserData;
    if isfield(cache, 'CursorSortedX') && isequal(cache.CursorSortedXDataLength, numel(lineHandle.XData))
        xData = cache.CursorSortedX;
        yData = cache.CursorSortedY;
        return;
    end

    rawX = double(lineHandle.XData(:));
    rawY = double(lineHandle.YData(:));
    valid = isfinite(rawX) & isfinite(rawY);
    rawX = rawX(valid);
    rawY = rawY(valid);
    if numel(rawX) >= 2
        [rawX, order] = sort(rawX);
        rawY = rawY(order);
        [rawX, uniqueIndex] = unique(rawX, 'stable');
        rawY = rawY(uniqueIndex);
    end

    cache.CursorSortedX = rawX;
    cache.CursorSortedY = rawY;
    cache.CursorSortedXDataLength = numel(lineHandle.XData);
    lineHandle.UserData = cache;
    xData = rawX;
    yData = rawY;
end

function active = is_target_active_at_time(userData, timeValue)
    active = false;
    if ~isfield(userData, 'modeTimes') || ~isfield(userData, 'modeNums') || ...
            isempty(userData.modeTimes) || isempty(userData.modeNums)
        return;
    end

    modeIndex = find(userData.modeTimes <= timeValue, 1, 'last');
    if isempty(modeIndex)
        modeIndex = 1;
    end
    activeModes = [4 5 6 8 9 10 11 12 15];
    active = ismember(userData.modeNums(modeIndex), activeModes);
end

function hide_target_cursor_objects(signalFigure)
    if ~isfield(signalFigure.UserData, 'targetTrajectory')
        return;
    end
    trajectory = signalFigure.UserData.targetTrajectory;
    objectNames = {'boatMarker', 'targetMarker', 'targetVector', 'targetLabel'};
    for objectIndex = 1:numel(objectNames)
        objectName = objectNames{objectIndex};
        if isfield(trajectory, objectName) && ~isempty(trajectory.(objectName))
            set_cursor_object_visibility(trajectory.(objectName), 'off');
        end
    end
    signalFigure.UserData.targetTrajectory = trajectory;
end

function update_ekf_or_gps_boat_marker(signalFigure, timeValue)
    userData = signalFigure.UserData;
    if ~isfield(userData, 'mapAxes') || ~isvalid(userData.mapAxes)
        return;
    end

    [latitude, longitude, hasPosition] = get_boat_position(signalFigure, timeValue);
    if ~hasPosition
        return;
    end
    heading = get_boat_heading(signalFigure, timeValue, NaN);
    userData.boatMarker = update_ship_marker(userData.mapAxes, ...
        userData.boatMarker, latitude, longitude, heading, 'c', ...
        signalFigure, timeValue);
    signalFigure.UserData.boatMarker = userData.boatMarker;
end

function marker = update_ship_marker( ...
    mapAxes, marker, latitude, longitude, heading, color, signalFigure, timeValue)
    if ~isfinite(heading)
        heading = 0;
    end
    if isempty(marker) || ~isstruct(marker)
        marker = struct('hull', gobjects(0), ...
            'leftRudder', gobjects(0), 'rightRudder', gobjects(0), ...
            'leftMotor', gobjects(0), 'rightMotor', gobjects(0), ...
            'leftThrust', gobjects(0), 'rightThrust', gobjects(0));
    end

    [leftRudderAngle, rightRudderAngle, leftRpm, leftDirection, ...
        rightRpm, rightDirection, maxMotorRpm] = ...
        get_boat_actuator_state(signalFigure, timeValue);

    headingRadians = deg2rad(heading);
    shipNorth = [7 2 -5 -5 2 7];
    shipEast = [0 -3 -3 3 3 0];
    north = shipNorth * cos(headingRadians) - shipEast * sin(headingRadians);
    east = shipNorth * sin(headingRadians) + shipEast * cos(headingRadians);
    [shipLatitude, shipLongitude] = boat_local_to_map( ...
        latitude, longitude, north, east);
    marker.hull = update_ship_line(mapAxes, marker.hull, ...
        shipLatitude, shipLongitude, color, 1.5, '-');

    [marker.leftRudder, marker.leftMotor, marker.leftThrust] = ...
        update_ship_actuator(mapAxes, marker.leftRudder, marker.leftMotor, ...
        marker.leftThrust, latitude, longitude, heading, -2, ...
        leftRudderAngle, leftRpm, leftDirection, maxMotorRpm, [1 0.8 0.1]);
    [marker.rightRudder, marker.rightMotor, marker.rightThrust] = ...
        update_ship_actuator(mapAxes, marker.rightRudder, marker.rightMotor, ...
        marker.rightThrust, latitude, longitude, heading, 2, ...
        rightRudderAngle, rightRpm, rightDirection, maxMotorRpm, [0.2 1 0.9]);
    bring_ship_to_front(marker);
end

function [leftRudderAngle, rightRudderAngle, leftRpm, leftDirection, ...
    rightRpm, rightDirection, maxMotorRpm] = get_boat_actuator_state(signalFigure, timeValue)
leftRudderAngle = sample_boat_actuator(signalFigure, 'leftRudder', timeValue, 0, 'linear');
rightRudderAngle = sample_boat_actuator(signalFigure, 'rightRudder', timeValue, 0, 'linear');
leftRpm = sample_boat_actuator(signalFigure, 'leftMotorRpm', timeValue, NaN, 'linear');
leftDirection = sample_boat_actuator(signalFigure, 'leftMotorDir', timeValue, 0, 'nearest');
rightRpm = sample_boat_actuator(signalFigure, 'rightMotorRpm', timeValue, NaN, 'linear');
rightDirection = sample_boat_actuator(signalFigure, 'rightMotorDir', timeValue, 0, 'nearest');
maxMotorRpm = NaN;
if isfield(signalFigure.UserData, 'boatActuators') && ...
        isfield(signalFigure.UserData.boatActuators, 'maxMotorRpm')
    maxMotorRpm = signalFigure.UserData.boatActuators.maxMotorRpm;
end
end

function value = sample_boat_actuator(signalFigure, signalName, timeValue, defaultValue, method)
value = defaultValue;
if ~isfield(signalFigure.UserData, 'boatActuators') || ...
        ~isfield(signalFigure.UserData.boatActuators, signalName)
    return;
end

signal = signalFigure.UserData.boatActuators.(signalName);
if isempty(signal.time)
    return;
elseif numel(signal.time) == 1
    value = signal.values(1);
elseif timeValue >= signal.time(1) && timeValue <= signal.time(end)
    value = interp1(signal.time, signal.values, timeValue, method);
end
end

function [rudder, motor, thrust] = update_ship_actuator( ...
    mapAxes, rudder, motor, thrust, latitude, longitude, heading, sideEast, ...
    rudderAngle, rpm, direction, maxMotorRpm, motorColor)
rudderAngle = min(max(rudderAngle, -45), 45);
rudderHeading = heading + 180 - rudderAngle;
axisNorth = cosd(rudderHeading);
axisEast = sind(rudderHeading);
mountNorth = -5 * cosd(heading) - sideEast * sind(heading);
mountEast = -5 * sind(heading) + sideEast * cosd(heading);

rudderStartNorth = mountNorth + 0.7 * axisNorth;
rudderStartEast = mountEast + 0.7 * axisEast;
rudderEndNorth = mountNorth + 5 * axisNorth;
rudderEndEast = mountEast + 5 * axisEast;
[rudderLat, rudderLon] = boat_local_to_map(latitude, longitude, ...
    [rudderStartNorth rudderEndNorth], [rudderStartEast rudderEndEast]);
rudder = update_ship_line(mapAxes, rudder, rudderLat, rudderLon, ...
    [1 1 1], 1.5, '--');

motorNorth = mountNorth + 0.4 * axisNorth;
motorEast = mountEast + 0.4 * axisEast;
[motorLat, motorLon] = boat_local_to_map(latitude, longitude, motorNorth, motorEast);
motor = update_ship_motor_marker(mapAxes, motor, motorLat, motorLon, motorColor);

if ~isfinite(rpm) || ~isfinite(maxMotorRpm) || maxMotorRpm <= 0 || ...
        ~isfinite(direction) || ...
        ~ismember(round(direction), [0 1]) || rpm == 0
    if ~isempty(thrust) && isvalid(thrust)
        thrust.Visible = 'off';
    end
    return;
end

thrustLength = 5 * min(abs(rpm) / maxMotorRpm, 1);
if thrustLength < 0.15
    if ~isempty(thrust) && isvalid(thrust)
        thrust.Visible = 'off';
    end
    return;
end

baseDistance = 0.8;
if round(direction) == 0
    tailDistance = baseDistance + thrustLength;
    tipDistance = baseDistance;
else
    tailDistance = baseDistance;
    tipDistance = baseDistance + thrustLength;
end
tailNorth = mountNorth + tailDistance * axisNorth;
tailEast = mountEast + tailDistance * axisEast;
tipNorth = mountNorth + tipDistance * axisNorth;
tipEast = mountEast + tipDistance * axisEast;
headLength = min(1.4, thrustLength * 0.45);
headHalfWidth = headLength * 0.6;
perpendicularNorth = -axisEast;
perpendicularEast = axisNorth;
wingBaseNorth = tipNorth - headLength * (tipNorth - tailNorth) / thrustLength;
wingBaseEast = tipEast - headLength * (tipEast - tailEast) / thrustLength;
wing1North = wingBaseNorth + headHalfWidth * perpendicularNorth;
wing1East = wingBaseEast + headHalfWidth * perpendicularEast;
wing2North = wingBaseNorth - headHalfWidth * perpendicularNorth;
wing2East = wingBaseEast - headHalfWidth * perpendicularEast;
[thrustLat, thrustLon] = boat_local_to_map(latitude, longitude, ...
    [tailNorth tipNorth wing1North tipNorth wing2North], ...
    [tailEast tipEast wing1East tipEast wing2East]);
thrust = update_ship_line(mapAxes, thrust, thrustLat, thrustLon, ...
    motorColor, 3.5, '-');
end

function [latitude, longitude] = boat_local_to_map(originLat, originLon, north, east)
metersPerDegree = 111320;
latitude = originLat + north / metersPerDegree;
longitude = originLon + east ./ ...
    (metersPerDegree * max(cosd(originLat), 0.01));
end

function lineHandle = update_ship_line( ...
    mapAxes, lineHandle, latitude, longitude, color, lineWidth, lineStyle)
if isempty(lineHandle) || ~isvalid(lineHandle)
    lineHandle = geoplot(mapAxes, latitude, longitude, ...
        'Color', color, 'LineWidth', lineWidth, 'LineStyle', lineStyle, ...
        'HandleVisibility', 'off');
else
    lineHandle.LatitudeData = latitude;
    lineHandle.LongitudeData = longitude;
end
lineHandle.Visible = 'on';
end

function marker = update_ship_motor_marker(mapAxes, marker, latitude, longitude, color)
if isempty(marker) || ~isvalid(marker)
    marker = geoscatter(mapAxes, latitude, longitude, 24, color, 'filled', ...
        'MarkerEdgeColor', 'k', 'HandleVisibility', 'off');
else
    marker.LatitudeData = latitude;
    marker.LongitudeData = longitude;
end
marker.Visible = 'on';
end

function set_cursor_object_visibility(object, visibility)
    if isstruct(object)
        fields = fieldnames(object);
        for fieldIndex = 1:numel(fields)
            child = object.(fields{fieldIndex});
            if ~isempty(child) && all(isvalid(child))
                child.Visible = visibility;
            end
        end
    elseif ~isempty(object) && all(isvalid(object))
        object.Visible = visibility;
    end
end

function bring_ship_to_front(marker)
    if isstruct(marker)
        fields = fieldnames(marker);
        shipHandles = gobjects(0);
        thrustHandles = gobjects(0);
        for fieldIndex = 1:numel(fields)
            child = marker.(fields{fieldIndex});
            if ~isempty(child) && all(isvalid(child))
                if startsWith(fields{fieldIndex}, 'leftThrust') || ...
                        startsWith(fields{fieldIndex}, 'rightThrust')
                    thrustHandles = [thrustHandles; child(:)]; %#ok<AGROW>
                else
                    shipHandles = [shipHandles; child(:)]; %#ok<AGROW>
                end
            end
        end
        if ~isempty(shipHandles)
            uistack(shipHandles, 'top');
        end
        if ~isempty(thrustHandles)
            uistack(thrustHandles, 'top');
        end
    elseif ~isempty(marker) && all(isvalid(marker))
        uistack(marker, 'top');
    end
end

function markerShape = get_ship_marker_shape(heading)
    direction = mod(heading + 45, 360);
    if direction < 90
        markerShape = '^';
    elseif direction < 180
        markerShape = '>';
    elseif direction < 270
        markerShape = 'v';
    else
        markerShape = '<';
    end
end

function heading = get_boat_heading(signalFigure, timeValue, fallbackHeading)
    heading = fallbackHeading;
    samplePeriod = 0.5;
    [latBefore, lonBefore, hasBefore] = get_boat_position(signalFigure, timeValue - samplePeriod);
    [latAfter, lonAfter, hasAfter] = get_boat_position(signalFigure, timeValue + samplePeriod);
    if hasBefore && hasAfter
        deltaNorth = latAfter - latBefore;
        deltaEast = (lonAfter - lonBefore) * cosd((latAfter + latBefore) / 2);
        if hypot(deltaNorth, deltaEast) > 1e-10
            heading = mod(rad2deg(atan2(deltaEast, deltaNorth)), 360);
        end
    end
end

function [latitude, longitude, hasPosition] = get_boat_position(signalFigure, timeValue)
    latitude = NaN;
    longitude = NaN;
    hasPosition = false;

    userData = signalFigure.UserData;
    sources = {'ekfTimeS', 'ekfLat', 'ekfLng'; ...
        'gpsTimeS', 'gpsLat', 'gpsLng'};
    cacheUpdated = false;
    for sourceIndex = 1:size(sources, 1)
        timeField = sources{sourceIndex, 1};
        latField = sources{sourceIndex, 2};
        lonField = sources{sourceIndex, 3};
        if ~isfield(userData, timeField) || ~isfield(userData, latField) || ...
                ~isfield(userData, lonField)
            continue;
        end

        cacheField = ['Sorted_' timeField];
        % Sorting/deduping the full EKF/GPS track on every mouse move is the
        % main cause of cursor lag on large logs, so cache it once per source.
        if isfield(userData, cacheField)
            cached = userData.(cacheField);
        else
            timeData = double(userData.(timeField)(:));
            latitudeData = double(userData.(latField)(:));
            longitudeData = double(userData.(lonField)(:));
            valid = isfinite(timeData) & isfinite(latitudeData) & isfinite(longitudeData);
            timeData = timeData(valid);
            latitudeData = latitudeData(valid);
            longitudeData = longitudeData(valid);
            if numel(timeData) >= 2
                [timeData, order] = sort(timeData);
                latitudeData = latitudeData(order);
                longitudeData = longitudeData(order);
                [timeData, uniqueIndex] = unique(timeData, 'stable');
                latitudeData = latitudeData(uniqueIndex);
                longitudeData = longitudeData(uniqueIndex);
            end
            cached = struct('Time', timeData, 'Lat', latitudeData, 'Lon', longitudeData);
            userData.(cacheField) = cached;
            cacheUpdated = true;
        end

        if numel(cached.Time) < 2 || timeValue < cached.Time(1) || timeValue > cached.Time(end)
            continue;
        end

        latitude = interp1(cached.Time, cached.Lat, timeValue, 'linear');
        longitude = interp1(cached.Time, cached.Lon, timeValue, 'linear');
        hasPosition = isfinite(latitude) && isfinite(longitude);
        if hasPosition
            break;
        end
    end

    if cacheUpdated
        signalFigure.UserData = userData;
    end
end

function deactivate_cursor_tool(signalFigure)
    if isempty(signalFigure) || ~isvalid(signalFigure) || ...
            ~isfield(signalFigure.UserData, 'cursorTool')
        return;
    end

    data = signalFigure.UserData.cursorTool;
    data.enabled = false;
    data.dragging = false;
    signalFigure.UserData.cursorTool = data;

    if isfield(signalFigure.UserData, 'cursorToggle') && ...
            isvalid(signalFigure.UserData.cursorToggle)
        toggle = signalFigure.UserData.cursorToggle;
        toggle.Value = false;
        toggle.String = 'Cursor: OFF';
        toggle.BackgroundColor = get(0, 'defaultuicontrolbackgroundcolor');
    end
    if cursor_tool_can_interact(data.axes)
        signalFigure.WindowButtonMotionFcn = [];
        signalFigure.WindowButtonUpFcn = [];
        signalFigure.WindowButtonDownFcn = [];
    end
    if ~isempty(data.cursorLine) && isvalid(data.cursorLine)
        data.cursorLine.Visible = 'off';
    end
end

function allowed = cursor_tool_can_interact(signalAxes)
    allowed = true;
    signalFigure = ancestor(signalAxes, 'figure');
    if isempty(signalFigure) || ~isvalid(signalFigure)
        allowed = false;
        return;
    end

    try
        zoomTool = zoom(signalFigure);
        panTool = pan(signalFigure);
        rotateTool = rotate3d(signalFigure);
        allowed = strcmpi(zoomTool.Enable, 'off') && ...
            strcmpi(panTool.Enable, 'off') && ...
            strcmpi(rotateTool.Enable, 'off');
    catch
        allowed = true;
    end
end

function update_boat_and_vector(signalFigure, trajectory, actualNorth, actualEast, targetNorth, targetEast, timeValue)
    mapAxes = trajectory.mapAxes;
    boatLat = trajectory.originLat + actualNorth / trajectory.metersPerDegree;
    boatLon = trajectory.originLon + actualEast / (trajectory.metersPerDegree * cosd(trajectory.originLat));
    targetLat = trajectory.originLat + targetNorth / trajectory.metersPerDegree;
    targetLon = trajectory.originLon + targetEast / (trajectory.metersPerDegree * cosd(trajectory.originLat));

    fallbackHeading = mod(rad2deg(atan2(targetEast - actualEast, ...
        targetNorth - actualNorth)), 360);
    heading = get_boat_heading(signalFigure, timeValue, fallbackHeading);
    trajectory.boatMarker = update_ship_marker(mapAxes, trajectory.boatMarker, ...
        boatLat, boatLon, heading, 'c', signalFigure, timeValue);

    if isempty(trajectory.targetMarker) || ~isvalid(trajectory.targetMarker)
        trajectory.targetMarker = geoscatter(mapAxes, targetLat, targetLon, ...
            80, 'y', 'filled', 'MarkerEdgeColor', 'k');
        uistack(trajectory.targetMarker, 'top');
    else
        trajectory.targetMarker.LatitudeData = targetLat;
        trajectory.targetMarker.LongitudeData = targetLon;
    end

    if isempty(trajectory.targetVector) || ~isvalid(trajectory.targetVector)
        trajectory.targetVector = geoplot(mapAxes, [boatLat targetLat], [boatLon targetLon], ...
            'Color', 'yellow', 'LineWidth', 2, 'HandleVisibility', 'off');
        uistack(trajectory.targetVector, 'top');
    else
        trajectory.targetVector.LatitudeData = [boatLat targetLat];
        trajectory.targetVector.LongitudeData = [boatLon targetLon];
    end

    set_cursor_object_visibility(trajectory.boatMarker, 'on');
    bring_ship_to_front(trajectory.boatMarker);
    trajectory.targetMarker.Visible = 'on';
    trajectory.targetVector.Visible = 'on';
    if ~isempty(trajectory.targetLabel) && isvalid(trajectory.targetLabel)
        trajectory.targetLabel.Visible = 'on';
    end

    trajectory.currentBoatLat = boatLat;
    trajectory.currentBoatLon = boatLon;
    trajectory.currentTargetLat = targetLat;
    trajectory.currentTargetLon = targetLon;
    signalFigure.UserData.targetTrajectory = trajectory;
end

function update_target_position_on_map(signalFigure)
    if isempty(signalFigure) || ~isvalid(signalFigure)
        return;
    end
    if ~isfield(signalFigure.UserData, 'targetTrajectory')
        return;
    end

    data = signalFigure.UserData.targetTrajectory;
    if isempty(data.time) || ~isfield(data, 'mapAxes') || ~isvalid(data.mapAxes)
        return;
    end

    point = get(data.axes, 'CurrentPoint');
    timeValue = point(1, 1);
    if ~isfinite(timeValue) || timeValue < data.time(1) || timeValue > data.time(end)
        return;
    end

    targetNorth = interp1(data.time, data.targetNorth, timeValue, 'linear');
    targetEast = interp1(data.time, data.targetEast, timeValue, 'linear');
    if ~isfinite(targetNorth) || ~isfinite(targetEast)
        return;
    end

    targetLat = data.originLat + targetNorth / data.metersPerDegree;
    targetLon = data.originLon + targetEast / (data.metersPerDegree * cosd(data.originLat));

    if isempty(data.targetMarker) || ~isvalid(data.targetMarker)
        data.targetMarker = geoscatter(data.mapAxes, targetLat, targetLon, ...
            80, 'y', 'filled', 'MarkerEdgeColor', 'k');
    else
        data.targetMarker.LatitudeData = targetLat;
        data.targetMarker.LongitudeData = targetLon;
    end

    if isempty(data.targetLabel) || ~isvalid(data.targetLabel)
        data.targetLabel = text(data.mapAxes, targetLat, targetLon, ' TARGET', ...
            'Color', 'yellow', 'FontWeight', 'bold', 'HandleVisibility', 'off');
    else
        data.targetLabel.Position = [targetLon targetLat 0];
    end

    uistack([data.targetMarker, data.targetLabel], 'top');
    data.currentTime = timeValue;
    data.currentNorth = targetNorth;
    data.currentEast = targetEast;
    data.currentLat = targetLat;
    data.currentLon = targetLon;
    signalFigure.UserData.targetTrajectory = data;
end

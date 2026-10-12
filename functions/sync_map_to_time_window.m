function sync_map_to_time_window(signalAxes, uic)
    if isempty(signalAxes) || ~isvalid(signalAxes) || isempty(uic) || ~isvalid(uic)
        return;
    end

    timeRange = xlim(signalAxes);
    if any(~isfinite(timeRange)) || timeRange(1) >= timeRange(2)
        return;
    end

    ud = uic.UserData;
    if ~isfield(ud, 'gax') || ~isvalid(ud.gax)
        return;
    end
    gax = ud.gax;

    gpsMask = ud.gpsTimeS >= timeRange(1) & ud.gpsTimeS <= timeRange(2);
    gpsLat = ud.gpsLat(gpsMask);
    gpsLng = ud.gpsLng(gpsMask);
    validGps = isfinite(gpsLat) & isfinite(gpsLng);
    gpsLat = gpsLat(validGps);
    gpsLng = gpsLng(validGps);

    if isfield(ud, 'gp') && ~isempty(ud.gp) && isvalid(ud.gp)
        delete(ud.gp);
    end
    ud.gp = gobjects(0);
    if ~isempty(gpsLat)
        ud.gp = geoscatter(gax, gpsLat, gpsLng, 10, [0.45 0.25 0.75], 'filled');
    end

    selectedLat = gpsLat;
    selectedLng = gpsLng;

    targetLat = [];
    targetLng = [];
    if isfield(ud, 'signalFigure') && isvalid(ud.signalFigure) && ...
            isfield(ud.signalFigure.UserData, 'targetTrajectory')
        trajectory = ud.signalFigure.UserData.targetTrajectory;
        if isfield(trajectory, 'targetTrack') && ~isempty(trajectory.targetTrack) && ...
                isvalid(trajectory.targetTrack)
            delete(trajectory.targetTrack);
        end
        trajectory.targetTrack = gobjects(0);
        targetMask = trajectory.time >= timeRange(1) & trajectory.time <= timeRange(2);
        targetNorth = trajectory.targetNorth(targetMask);
        targetEast = trajectory.targetEast(targetMask);
        validTarget = isfinite(targetNorth) & isfinite(targetEast);
        targetNorth = targetNorth(validTarget);
        targetEast = targetEast(validTarget);
        if numel(targetNorth) > 1
            targetLat = trajectory.originLat + targetNorth / trajectory.metersPerDegree;
            targetLng = trajectory.originLon + targetEast / ...
                (trajectory.metersPerDegree * cosd(trajectory.originLat));
            trajectory.targetTrack = geoplot(gax, targetLat, targetLng, ...
                'Color', 'yellow', 'LineWidth', 2, 'HandleVisibility', 'off');
            uistack(trajectory.targetTrack, 'top');
            selectedLat = [selectedLat; targetLat(:)];
            selectedLng = [selectedLng; targetLng(:)];
        end
        ud.signalFigure.UserData.targetTrajectory = trajectory;
    end

    ekfLat = [];
    ekfLng = [];
    if isfield(ud, 'ekfTrack') && ~isempty(ud.ekfTrack) && isvalid(ud.ekfTrack)
        delete(ud.ekfTrack);
    end
    if isfield(ud, 'ekfStart') && ~isempty(ud.ekfStart) && isvalid(ud.ekfStart)
        delete(ud.ekfStart);
    end
    if isfield(ud, 'ekfEnd') && ~isempty(ud.ekfEnd) && isvalid(ud.ekfEnd)
        delete(ud.ekfEnd);
    end
    ud.ekfTrack = gobjects(0);
    ud.ekfStart = gobjects(0);
    ud.ekfEnd = gobjects(0);

    if isfield(ud, 'ekfTimeS') && ~isempty(ud.ekfTimeS)
        ekfMask = ud.ekfTimeS >= timeRange(1) & ud.ekfTimeS <= timeRange(2);
        ekfLat = ud.ekfLat(ekfMask);
        ekfLng = ud.ekfLng(ekfMask);
        ekfSpeed = ud.ekfSpeed(ekfMask);
        validEkf = isfinite(ekfLat) & isfinite(ekfLng) & isfinite(ekfSpeed);
        ekfLat = ekfLat(validEkf);
        ekfLng = ekfLng(validEkf);
        ekfSpeed = ekfSpeed(validEkf);
        if numel(ekfLat) > 1
            speedMin = min(ekfSpeed);
            speedMax = max(ekfSpeed);
            padding = max(0.1 * (speedMax - speedMin), max(abs(speedMin) * 0.1, 1));
            if speedMin == speedMax
                padding = max(abs(speedMin) * 0.1, 1);
            end
            clim(gax, [speedMin - padding, speedMax + padding]);
            ud.ekfTrack = geoscatter(gax, ekfLat, ekfLng, 10, ekfSpeed, 'filled');
            ud.ekfStart = geoscatter(gax, ekfLat(1), ekfLng(1), 50, 'g', 'filled');
            ud.ekfEnd = geoscatter(gax, ekfLat(end), ekfLng(end), 50, 'w', 'filled');
            selectedLat = [selectedLat; ekfLat(:)];
            selectedLng = [selectedLng; ekfLng(:)];
            uistack([ud.ekfTrack, ud.ekfStart, ud.ekfEnd], 'top');
        end
    end

    if isfield(ud, 'cb') && isvalid(ud.cb)
        ud.cb.Visible = 'on';
    end

    if ~isempty(selectedLat)
        latMin = min(selectedLat);
        latMax = max(selectedLat);
        lngMin = min(selectedLng);
        lngMax = max(selectedLng);
        latSpan = max(latMax - latMin, 1e-5);
        lngSpan = max(lngMax - lngMin, 1e-5);
        geolimits(gax, [latMin - 0.05 * latSpan, latMax + 0.05 * latSpan], ...
            [lngMin - 0.05 * lngSpan, lngMax + 0.05 * lngSpan]);
        if isfield(ud, 'refLat') && isfield(ud, 'refLng')
            updateMeterLabels(gax, ud.refLat, ud.refLng);
        end
    end

    uic.UserData = ud;
end

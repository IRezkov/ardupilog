function zoomToMode(src, ~, modeTimes, durations)
    idx     = src.Value;
    tStart  = modeTimes(idx);
    tDur    = durations(idx);
    tStop   = tStart + tDur;
    margin  = 0.05 * tDur;

    xlim(gca, [tStart - margin, tStop + margin]);

    ud = src.UserData;
    if isfield(ud, 'gp') && ~isempty(ud.gp) && all(isvalid(ud.gp))
        gpsT  = ud.gpsTimeS;
        mask  = gpsT >= tStart & gpsT <= tStop;

        latSeg   = ud.gpsLat(mask);
        lonSeg   = ud.gpsLng(mask);

        if isempty(latSeg)
            src.UserData = ud;
            return;
        end

        valid = isfinite(latSeg) & isfinite(lonSeg);
        latSeg   = latSeg(valid);
        lonSeg   = lonSeg(valid);

        if isempty(latSeg)
            src.UserData = ud;
            return;
        end

        [latLim, lonLim] = geolimits(ud.gax);

        delete(ud.gp);

        ud.gp = geoscatter(ud.gax, latSeg, lonSeg, 30, [0.45 0.25 0.75], 'filled');

        targetLatSeg = [];
        targetLonSeg = [];
        ekfLatSeg = [];
        ekfLngSeg = [];
        if isfield(ud, 'signalFigure') && isvalid(ud.signalFigure) && ...
                isfield(ud.signalFigure.UserData, 'targetTrajectory')
            trajectory = ud.signalFigure.UserData.targetTrajectory;
                if isfield(trajectory, 'targetTrack') && ~isempty(trajectory.targetTrack) && ...
                    all(isvalid(trajectory.targetTrack))
                delete(trajectory.targetTrack);
            end
            trajectory.targetTrack = gobjects(0);
            targetMask = trajectory.time >= tStart & trajectory.time <= tStop;
            targetNorth = trajectory.targetNorth(targetMask);
            targetEast = trajectory.targetEast(targetMask);
            validTarget = isfinite(targetNorth) & isfinite(targetEast);
            targetNorth = targetNorth(validTarget);
            targetEast = targetEast(validTarget);
            if numel(targetNorth) > 1
                targetLatSeg = trajectory.originLat + targetNorth / trajectory.metersPerDegree;
                targetLonSeg = trajectory.originLon + targetEast / ...
                    (trajectory.metersPerDegree * cosd(trajectory.originLat));
                trajectory.targetTrack = geoplot(ud.gax, targetLatSeg, targetLonSeg, ...
                    'Color', 'yellow', 'LineWidth', 2, 'HandleVisibility', 'off');
                uistack(trajectory.targetTrack, 'top');
            end
            ud.signalFigure.UserData.targetTrajectory = trajectory;
        end

        if isfield(ud, 'ekfTrack') && ~isempty(ud.ekfTrack) && all(isvalid(ud.ekfTrack))
            delete(ud.ekfTrack);
        end
        if isfield(ud, 'ekfStart') && ~isempty(ud.ekfStart) && all(isvalid(ud.ekfStart))
            delete(ud.ekfStart);
        end
        if isfield(ud, 'ekfEnd') && ~isempty(ud.ekfEnd) && all(isvalid(ud.ekfEnd))
            delete(ud.ekfEnd);
        end

        ud.ekfTrack = gobjects(0);
        ud.ekfStart = gobjects(0);
        ud.ekfEnd = gobjects(0);
        if isfield(ud, 'ekfTimeS') && ~isempty(ud.ekfTimeS)
            ekfMask = ud.ekfTimeS >= tStart & ud.ekfTimeS <= tStop;
            ekfLatSeg = ud.ekfLat(ekfMask);
            ekfLngSeg = ud.ekfLng(ekfMask);
            ekfSpeedSeg = ud.ekfSpeed(ekfMask);
            validEkf = isfinite(ekfLatSeg) & isfinite(ekfLngSeg) & isfinite(ekfSpeedSeg);
            ekfLatSeg = ekfLatSeg(validEkf);
            ekfLngSeg = ekfLngSeg(validEkf);
            ekfSpeedSeg = ekfSpeedSeg(validEkf);
            if numel(ekfLatSeg) > 1
                speedMin = min(ekfSpeedSeg);
                speedMax = max(ekfSpeedSeg);
                if speedMin == speedMax
                    padding = max(abs(speedMin) * 0.1, 1);
                else
                    padding = 0.1 * (speedMax - speedMin);
                end
                clim(ud.gax, [speedMin - padding speedMax + padding]);
                ud.ekfTrack = geoscatter(ud.gax, ekfLatSeg, ekfLngSeg, 10, ekfSpeedSeg, 'filled');
                ud.ekfStart = geoscatter(ud.gax, ekfLatSeg(1), ekfLngSeg(1), 50, 'g', 'filled');
                ud.ekfEnd = geoscatter(ud.gax, ekfLatSeg(end), ekfLngSeg(end), 50, 'w', 'filled');
                uistack([ud.ekfTrack, ud.ekfStart, ud.ekfEnd], 'top');
            end
        end

        % Восстанавливаем colorbar, если он пропал
        if isfield(ud, 'cb') && isvalid(ud.cb)
            ud.cb.Visible = 'on';
        else
            ud.cb = colorbar(ud.gax);
            ud.cb.Label.String = 'Скорость, км/ч';
            ud.cb.Label.FontSize = 9;
        end

        geolimits(ud.gax, latLim, lonLim);
        % После строки geolimits(ud.gax, latLim, lonLim):
        if isfield(ud, 'refLat') && isfield(ud, 'refLng')
            updateMeterLabels(ud.gax, ud.refLat, ud.refLng);
        end


        allLat = latSeg;
        allLon = lonSeg;
        if ~isempty(ekfLatSeg)
            allLat = [allLat; ekfLatSeg];
            allLon = [allLon; ekfLngSeg];
        end
        if ~isempty(targetLatSeg)
            allLat = [allLat; targetLatSeg];
            allLon = [allLon; targetLonSeg];
        end
        latMin = min(allLat); latMax = max(allLat);
        lonMin = min(allLon); lonMax = max(allLon);

        outOfBounds = latMin < latLim(1) || latMax > latLim(2) || ...
                      lonMin < lonLim(1) || lonMax > lonLim(2);

        if outOfBounds
            pad = 0.05;
            latSpan = max(latMax - latMin, 1e-4);
            lonSpan = max(lonMax - lonMin, 1e-4);

            geolimits(ud.gax, ...
                [latMin - pad*latSpan, latMax + pad*latSpan], ...
                [lonMin - pad*lonSpan, lonMax + pad*lonSpan]);
            % После строки geolimits(ud.gax, latLim, lonLim):
            if isfield(ud, 'refLat') && isfield(ud, 'refLng')
                updateMeterLabels(ud.gax, ud.refLat, ud.refLng);
            end
        end
    end

    src.UserData = ud;
    if isfield(ud, 'signalFigure') && isvalid(ud.signalFigure)
        sync_map_to_time_window(ud.signalFigure.CurrentAxes, src);
    end
end

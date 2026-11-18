function trackLengths = calculate_mode_track_lengths(logObj, t0, modeTimes, durations)
%CALCULATE_MODE_TRACK_LENGTHS Calculate actual track distance for mode intervals.

modeCount = min(numel(modeTimes), numel(durations));
trackLengths = zeros(modeCount, 1);
if modeCount == 0
    return;
end

gpsAvailable = false;
gpsTime = [];
gpsLat = [];
gpsLng = [];
if isprop(logObj, 'GPS') && ~isempty(logObj.GPS)
    gpsObj = logObj.GPS;
    if all([isprop(gpsObj, 'TimeS'), isprop(gpsObj, 'Lat'), ...
            isprop(gpsObj, 'Lng')])
        gpsCount = min([numel(gpsObj.TimeS), numel(gpsObj.Lat), numel(gpsObj.Lng)]);
        gpsTime = double(gpsObj.TimeS(1:gpsCount));
        gpsLat = double(gpsObj.Lat(1:gpsCount));
        gpsLng = double(gpsObj.Lng(1:gpsCount));
        if isprop(gpsObj, 'Status')
            gpsStatus = double(gpsObj.Status(1:gpsCount));
            gpsValid = isfinite(gpsStatus) & gpsStatus >= 3;
        else
            gpsValid = true(gpsCount, 1);
        end
        gpsValid = gpsValid & isfinite(gpsTime) & isfinite(gpsLat) & isfinite(gpsLng) & ...
            abs(gpsLat) <= 90 & abs(gpsLng) <= 180;
        gpsTime = gpsTime(gpsValid);
        gpsLat = gpsLat(gpsValid);
        gpsLng = gpsLng(gpsValid);
        if numel(gpsTime) > 1
            [gpsTime, gpsOrder] = sort(gpsTime);
            gpsLat = gpsLat(gpsOrder);
            gpsLng = gpsLng(gpsOrder);
            [gpsTime, uniqueIndex] = unique(gpsTime, 'stable');
            gpsLat = gpsLat(uniqueIndex);
            gpsLng = gpsLng(uniqueIndex);
            gpsAvailable = numel(gpsTime) > 1;
        end
    end
end

ekfAvailable = false;
ekfTime = [];
ekfEast = [];
ekfNorth = [];
if isprop(logObj, 'XKF1') && ~isempty(logObj.XKF1)
    xkf = logObj.XKF1;
    if all([isprop(xkf, 'TimeS'), isprop(xkf, 'PE'), isprop(xkf, 'PN')])
        ekfCount = min([numel(xkf.TimeS), numel(xkf.PE), numel(xkf.PN)]);
        ekfTime = double(xkf.TimeS(1:ekfCount));
        ekfEast = double(xkf.PE(1:ekfCount));
        ekfNorth = double(xkf.PN(1:ekfCount));
        ekfValid = isfinite(ekfTime) & isfinite(ekfEast) & isfinite(ekfNorth);
        ekfTime = ekfTime(ekfValid);
        ekfEast = ekfEast(ekfValid);
        ekfNorth = ekfNorth(ekfValid);
        if numel(ekfTime) > 1
            [ekfTime, ekfOrder] = sort(ekfTime);
            ekfEast = ekfEast(ekfOrder);
            ekfNorth = ekfNorth(ekfOrder);
            [ekfTime, uniqueIndex] = unique(ekfTime, 'stable');
            ekfEast = ekfEast(uniqueIndex);
            ekfNorth = ekfNorth(uniqueIndex);
            ekfAvailable = numel(ekfTime) > 1;
        end
    end
end

earthRadius = 6371000;
for i = 1:modeCount
    tStart = t0 + modeTimes(i);
    tStop = tStart + durations(i);

    if gpsAvailable
        segmentMask = gpsTime >= tStart & gpsTime <= tStop;
        segmentLat = gpsLat(segmentMask);
        segmentLng = gpsLng(segmentMask);
        if numel(segmentLat) > 1
            lat1 = deg2rad(segmentLat(1:end-1));
            lat2 = deg2rad(segmentLat(2:end));
            deltaLat = lat2 - lat1;
            deltaLng = deg2rad(segmentLng(2:end) - segmentLng(1:end-1));
            a = sin(deltaLat/2).^2 + cos(lat1).*cos(lat2).*sin(deltaLng/2).^2;
            a = min(max(a, 0), 1);
            segmentDistance = earthRadius * sum(2 * atan2(sqrt(a), sqrt(1-a)));
            trackLengths(i) = segmentDistance;
        end
    elseif ekfAvailable
        segmentMask = ekfTime >= tStart & ekfTime <= tStop;
        segmentEast = ekfEast(segmentMask);
        segmentNorth = ekfNorth(segmentMask);
        if numel(segmentEast) > 1
            trackLengths(i) = sum(hypot(diff(segmentEast), diff(segmentNorth)));
        end
    end
end
end

function [track, available] = build_plot2_local_ekf_track(logObj)
%BUILD_PLOT2_LOCAL_EKF_TRACK Return valid local East/North XKF1 positions.

track = struct('time', [], 'east', [], 'north', []);
available = false;
if isempty(logObj) || ~isobject(logObj) || ~isprop(logObj, 'XKF1') || ...
        isempty(logObj.XKF1)
    return;
end

xkf = logObj.XKF1;
if ~all([isprop(xkf, 'TimeS'), isprop(xkf, 'PN'), isprop(xkf, 'PE')])
    return;
end

sampleCount = min([numel(xkf.TimeS), numel(xkf.PN), numel(xkf.PE)]);
timeValues = double(xkf.TimeS(1:sampleCount));
northValues = double(xkf.PN(1:sampleCount));
eastValues = double(xkf.PE(1:sampleCount));
validValues = isfinite(timeValues) & isfinite(northValues) & isfinite(eastValues);
timeValues = timeValues(validValues);
northValues = northValues(validValues);
eastValues = eastValues(validValues);
if numel(timeValues) < 2
    return;
end

[timeValues, timeOrder] = sort(timeValues);
northValues = northValues(timeOrder);
eastValues = eastValues(timeOrder);
[timeValues, uniqueIndex] = unique(timeValues, 'stable');
northValues = northValues(uniqueIndex);
eastValues = eastValues(uniqueIndex);
if numel(timeValues) < 2
    return;
end

track.time = timeValues;
track.east = eastValues;
track.north = northValues;
available = true;
end
function [jumpCount, jumpSummary] = detect_log_jumps(log)
%DETECT_LOG_JUMPS Estimate jumps using IMU free-fall followed by impact.

freeFallThresholdMps2 = 3;
impactThresholdMps2 = 15;
minimumFreeFallDurationSec = 0.08;
maximumImpactDelaySec = 0.8;

jumpCount = NaN;
jumpSummary = 'Not assessed: IMU acceleration telemetry unavailable';

if isstruct(log)
    logProperties = fieldnames(log);
elseif isobject(log)
    logProperties = properties(log);
else
    return;
end

imuGroups = logProperties(cellfun(@(name) ...
    ~isempty(regexp(name, '^IMU\d*$', 'once')), logProperties));
selectedGroup = [];
selectedCount = 0;
for groupIndex = 1:numel(imuGroups)
    imuLog = get_field_value(log, imuGroups{groupIndex});
    timeValues = get_field_value(imuLog, 'TimeS');
    accX = get_field_value(imuLog, 'AccX');
    accY = get_field_value(imuLog, 'AccY');
    accZ = get_field_value(imuLog, 'AccZ');
    sampleCount = min([numel(timeValues), numel(accX), numel(accY), numel(accZ)]);
    if sampleCount > selectedCount
        selectedGroup = {timeValues, accX, accY, accZ};
        selectedCount = sampleCount;
    end
end

if selectedCount < 2
    return;
end

timeValues = double(selectedGroup{1}(:));
accX = double(selectedGroup{2}(:));
accY = double(selectedGroup{3}(:));
accZ = double(selectedGroup{4}(:));
timeValues = timeValues(1:selectedCount);
accX = accX(1:selectedCount);
accY = accY(1:selectedCount);
accZ = accZ(1:selectedCount);
accMagnitude = sqrt(accX.^2 + accY.^2 + accZ.^2);
valid = isfinite(timeValues) & timeValues >= 0 & isfinite(accMagnitude);
timeValues = timeValues(valid);
accMagnitude = accMagnitude(valid);
if numel(timeValues) < 2
    return;
end

[timeValues, order] = sort(timeValues);
accMagnitude = accMagnitude(order);
[timeValues, uniqueIndices] = unique(timeValues, 'stable');
accMagnitude = accMagnitude(uniqueIndices);
if numel(timeValues) < 2
    return;
end

positiveIntervals = diff(timeValues);
positiveIntervals = positiveIntervals(positiveIntervals > 0 & isfinite(positiveIntervals));
if isempty(positiveIntervals)
    return;
end
maximumContinuousGapSec = max(0.15, 5 * median(positiveIntervals));
timeGaps = diff(timeValues) > maximumContinuousGapSec;
belowFreeFall = accMagnitude < freeFallThresholdMps2;
runStarts = find(belowFreeFall & [true; ~belowFreeFall(1:end-1) | timeGaps]);
runEnds = find(belowFreeFall & [~belowFreeFall(2:end) | timeGaps; true]);

jumpTimes = [];
for runIndex = 1:numel(runStarts)
    runStart = runStarts(runIndex);
    runEnd = runEnds(runIndex);
    if timeValues(runEnd) - timeValues(runStart) < minimumFreeFallDurationSec
        continue;
    end

    impactIndices = find(timeValues > timeValues(runEnd) & ...
        timeValues <= timeValues(runEnd) + maximumImpactDelaySec);
    if any(accMagnitude(impactIndices) >= impactThresholdMps2)
        jumpTimes(end + 1) = timeValues(runStart);
    end
end

if ~isempty(jumpTimes)
    mergedTimes = jumpTimes(1);
    for eventIndex = 2:numel(jumpTimes)
        if jumpTimes(eventIndex) - mergedTimes(end) > maximumImpactDelaySec
            mergedTimes(end + 1) = jumpTimes(eventIndex);
        end
    end
    jumpTimes = mergedTimes;
end

jumpCount = numel(jumpTimes);
thresholdText = sprintf( ...
    'heuristic: |a| < %.1f m/s^2 for >= %.2f s, then |a| >= %.1f m/s^2 within %.1f s', ...
    freeFallThresholdMps2, minimumFreeFallDurationSec, ...
    impactThresholdMps2, maximumImpactDelaySec);
if jumpCount == 0
    jumpSummary = sprintf('No likely jumps detected (%s)', thresholdText);
else
    timeTexts = arrayfun(@(timeValue) sprintf('%.1f s', timeValue), ...
        jumpTimes, 'UniformOutput', false);
    jumpSummary = sprintf('%d likely jump(s) at %s (%s)', ...
        jumpCount, strjoin(timeTexts, ', '), thresholdText);
end
end

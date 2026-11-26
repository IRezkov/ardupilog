function info = summarize_wheel_slip(log)
%SUMMARIZE_WHEEL_SLIP Find sustained wheel-speed imbalance events.

info = struct( ...
    'Summary', 'Not assessed (insufficient wheel speed telemetry)', ...
    'WheelIds', [], ...
    'DurationsSec', [], ...
    'EpisodeCounts', [], ...
    'SlowSpeedThreshold', 20, ...
    'FastSpeedThreshold', 200, ...
    'MinimumEpisodeSec', 0.5);

if isstruct(log)
    logProperties = fieldnames(log);
elseif isobject(log)
    logProperties = properties(log);
else
    logProperties = {};
end
wheelGroups = logProperties(cellfun(@(name) ...
    ~isempty(regexp(name, '^WTLM\d*$', 'once')), logProperties));
allIds = [];
allTimes = [];
allSpeeds = [];
for groupIndex = 1:numel(wheelGroups)
    wheelLog = get_field_value(log, wheelGroups{groupIndex});
    ids = get_field_value(wheelLog, 'id');
    if isempty(ids)
        ids = get_field_value(wheelLog, 'ID');
    end
    times = get_field_value(wheelLog, 'TimeS');
    speeds = get_field_value(wheelLog, 'Spd');
    if ~isnumeric(ids) || ~isnumeric(times) || ~isnumeric(speeds) || ...
            numel(ids) ~= numel(times) || numel(ids) ~= numel(speeds)
        continue;
    end

    ids = double(ids(:));
    times = double(times(:));
    speeds = abs(double(speeds(:)));
    valid = isfinite(ids) & isfinite(times) & isfinite(speeds);
    allIds = [allIds; ids(valid)]; %#ok<AGROW>
    allTimes = [allTimes; times(valid)]; %#ok<AGROW>
    allSpeeds = [allSpeeds; speeds(valid)]; %#ok<AGROW>
end

wheelIds = unique(allIds);
if numel(wheelIds) < 2
    return;
end

wheelTimes = cell(numel(wheelIds), 1);
wheelSpeeds = cell(numel(wheelIds), 1);
samplePeriods = nan(numel(wheelIds), 1);
for wheelIndex = 1:numel(wheelIds)
    mask = allIds == wheelIds(wheelIndex);
    [sortedTimes, order] = sort(allTimes(mask));
    sortedSpeeds = allSpeeds(mask);
    sortedSpeeds = sortedSpeeds(order);
    [wheelTimes{wheelIndex}, uniqueIndices] = unique(sortedTimes, 'last');
    wheelSpeeds{wheelIndex} = sortedSpeeds(uniqueIndices);
    intervals = diff(wheelTimes{wheelIndex});
    intervals = intervals(isfinite(intervals) & intervals > 0);
    if ~isempty(intervals)
        samplePeriods(wheelIndex) = median(intervals);
    end
end

usableWheels = isfinite(samplePeriods) & samplePeriods > 0;
wheelIds = wheelIds(usableWheels);
wheelTimes = wheelTimes(usableWheels);
wheelSpeeds = wheelSpeeds(usableWheels);
samplePeriods = samplePeriods(usableWheels);
if numel(wheelIds) < 2
    return;
end

sampleStep = median(samplePeriods);
startTime = max(cellfun(@(values) values(1), wheelTimes));
endTime = min(cellfun(@(values) values(end), wheelTimes));
if ~isfinite(sampleStep) || sampleStep <= 0 || endTime <= startTime
    return;
end
sampleTimes = (startTime:sampleStep:endTime)';
wheelSpeedMatrix = nan(numel(sampleTimes), numel(wheelIds));
maximumSampleAge = min(0.1, max(0.05, 2 * sampleStep));
for wheelIndex = 1:numel(wheelIds)
    nearestIndex = interp1(wheelTimes{wheelIndex}, ...
        1:numel(wheelTimes{wheelIndex}), sampleTimes, 'nearest', NaN);
    valid = isfinite(nearestIndex);
    sampleIndices = max(1, round(nearestIndex(valid)));
    sampleAges = abs(sampleTimes(valid) - wheelTimes{wheelIndex}(sampleIndices));
    validIndices = find(valid);
    validIndices(sampleAges > maximumSampleAge) = [];
    sampleIndices(sampleAges > maximumSampleAge) = [];
    wheelSpeedMatrix(validIndices, wheelIndex) = ...
        wheelSpeeds{wheelIndex}(sampleIndices);
end

detectedIds = [];
detectedDurations = [];
detectedEpisodeCounts = [];
for wheelIndex = 1:numel(wheelIds)
    otherWheelIndices = setdiff(1:numel(wheelIds), wheelIndex);
    anotherWheelIsFast = any( ...
        wheelSpeedMatrix(:, otherWheelIndices) >= info.FastSpeedThreshold, 2);
    thisWheelIsSlow = wheelSpeedMatrix(:, wheelIndex) <= info.SlowSpeedThreshold;
    eventMask = thisWheelIsSlow & anotherWheelIsFast & ...
        isfinite(wheelSpeedMatrix(:, wheelIndex));

    edges = diff([false; eventMask; false]);
    episodeStarts = find(edges == 1);
    episodeStops = find(edges == -1) - 1;
    episodeDurations = sampleTimes(episodeStops) - sampleTimes(episodeStarts);
    sustainedEpisodes = episodeDurations >= info.MinimumEpisodeSec - 1e-9;
    if any(sustainedEpisodes)
        detectedIds(end + 1) = wheelIds(wheelIndex); %#ok<AGROW>
        detectedDurations(end + 1) = sum(episodeDurations(sustainedEpisodes)); %#ok<AGROW>
        detectedEpisodeCounts(end + 1) = nnz(sustainedEpisodes); %#ok<AGROW>
    end
end

if isempty(detectedIds)
    info.Summary = 'No sustained wheel-speed imbalance detected';
    return;
end

info.WheelIds = detectedIds;
info.DurationsSec = detectedDurations;
info.EpisodeCounts = detectedEpisodeCounts;
summaryParts = cell(1, numel(detectedIds));
for wheelIndex = 1:numel(detectedIds)
    summaryParts{wheelIndex} = sprintf('Wheel %g: %.1f s', ...
        detectedIds(wheelIndex), detectedDurations(wheelIndex));
end
info.Summary = strjoin(summaryParts, '; ');
end

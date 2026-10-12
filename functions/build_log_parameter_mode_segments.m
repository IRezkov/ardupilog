function segments = build_log_parameter_mode_segments(log, rec, preserveRepeatedModes)
    segments = {};
    if isempty(log) || isempty(rec)
        return;
    end
    if nargin < 3
        preserveRepeatedModes = false;
    end

    modeObj = get_field_value(log, 'MODE');
    modeTimes = [];
    modeVals = [];
    if ~isempty(modeObj)
        modeTimes = double(get_field_value(modeObj, 'TimeS'));
        modeVals = double(get_field_value(modeObj, 'Mode'));
        if ~isempty(modeTimes) && ~isempty(modeVals) && numel(modeTimes) == numel(modeVals)
            modeTimes = modeTimes(:);
            modeVals = modeVals(:);
            [modeTimes, ord] = sort(modeTimes);
            modeVals = modeVals(ord);
        else
            modeTimes = [];
            modeVals = [];
        end
    end

    parmObj = get_field_value(log, 'PARM');
    parmTimes = [];
    parmNamesRaw = [];
    parmValsRaw = [];
    if ~isempty(parmObj)
        parmTimes = double(get_field_value(parmObj, 'TimeS'));
        parmNamesRaw = get_field_value(parmObj, 'Name');
        parmValsRaw = get_field_value(parmObj, 'Value');
    end

    if isfield(rec, 'StartTimeSec') && ~isempty(rec.StartTimeSec) && isscalar(rec.StartTimeSec)
        logStartTime = double(rec.StartTimeSec);
    else
        timeCandidates = [modeTimes(:); parmTimes(:)];
        timeCandidates = timeCandidates(isfinite(timeCandidates));
        if isempty(timeCandidates)
            logStartTime = 0;
        else
            logStartTime = min(timeCandidates);
        end
    end

    boundaries = [];
    if ~isempty(modeTimes)
        boundaries = [boundaries; modeTimes(:)];
    end

    boundaries = sort(unique(boundaries(~isnan(boundaries))));
    if isempty(boundaries)
        seg = rec;
        seg.StartTimeSec = 0;
        seg.EndTimeSec = max([logStartTime; double(parmTimes(:)); double(modeTimes(:))]) - logStartTime;
        seg.DurationSec = max(seg.EndTimeSec - seg.StartTimeSec, 0);
        seg.MainMode = 'UNKNOWN';
        seg.ModeSummary = '';
        seg.ChangedParams = '';
        if ~isempty(modeTimes)
            modeInfo = summarize_mode_window(modeTimes, modeVals, min(modeTimes), max(modeTimes));
            seg.MainMode = modeInfo.mainMode;
            seg.ModeSummary = modeInfo.summaryText;
        end
        if ~isempty(parmTimes) && ~isempty(parmNamesRaw) && ~isempty(parmValsRaw)
            seg.ChangedParams = summarize_param_window(parmNamesRaw, parmValsRaw, parmTimes, min([0; parmTimes(:)]), max([0; parmTimes(:)]) + 1e-9);
        end
        segments{end + 1} = apply_segment_metrics(seg, log, logStartTime);
        return;
    end

    startT = logStartTime;
    endT = max([logStartTime; modeTimes(:); parmTimes(:)]);
    if isempty(startT) || isempty(endT)
        startT = 0;
        endT = 0;
    end

    segmentTimes = unique([startT; boundaries(:); endT]);
    segmentTimes = sort(segmentTimes);
    for s = 1:(numel(segmentTimes)-1)
        segStart = segmentTimes(s);
        segEnd = segmentTimes(s + 1);
        if segEnd <= segStart
            continue;
        end

        modeInfo = summarize_mode_window(modeTimes, modeVals, segStart, segEnd);
        paramText = summarize_param_window(parmNamesRaw, parmValsRaw, parmTimes, segStart, segEnd);

        seg = rec;
        seg.StartTimeSec = segStart - logStartTime;
        seg.EndTimeSec = segEnd - logStartTime;
        seg.DurationSec = segEnd - segStart;
        seg.MainMode = modeInfo.mainMode;
        seg.ModeSummary = modeInfo.summaryText;
        seg.ChangedParams = paramText;

        if isempty(seg.ChangedParams) && isempty(seg.ModeSummary)
            if numel(segmentTimes) > 2
                continue;
            end
        end

        segments{end + 1} = apply_segment_metrics(seg, log, logStartTime);
    end

    if isempty(segments)
        seg = rec;
        seg.StartTimeSec = startT - logStartTime;
        seg.EndTimeSec = endT - logStartTime;
        seg.DurationSec = max(endT - startT, 0);
        seg.MainMode = 'UNKNOWN';
        seg.ModeSummary = '';
        seg.ChangedParams = '';
        if ~isempty(modeTimes)
            modeInfo = summarize_mode_window(modeTimes, modeVals, startT, endT);
            seg.MainMode = modeInfo.mainMode;
            seg.ModeSummary = modeInfo.summaryText;
        end
        segments{end + 1} = apply_segment_metrics(seg, log, logStartTime);
    end

    segments = merge_consecutive_segments(segments, log, logStartTime, preserveRepeatedModes);
end

function segments = merge_consecutive_segments(segments, log, logStartTime, preserveRepeatedModes)
    if isempty(segments)
        return;
    end

    merged = {};
    currentGroup = {};
    hasModeSinceParam = false;
    for k = 1:numel(segments)
        current = segments{k};
        if isempty(current)
            continue;
        end

        % A parameter event starts a new test window. Consecutive parameter
        % events stay in the same window and following mode segments join it.
        if ~isempty(current.ChangedParams) && hasModeSinceParam && ~isempty(currentGroup)
            merged{end + 1} = merge_segment_group(currentGroup, preserveRepeatedModes);
            currentGroup = {};
            hasModeSinceParam = false;
        elseif isempty(current.ChangedParams)
            hasModeSinceParam = true;
        end

        currentGroup{end + 1} = current;
    end

    if ~isempty(currentGroup)
        merged{end + 1} = merge_segment_group(currentGroup, preserveRepeatedModes);
    end

    if ~isempty(merged) && merged{1}.StartTimeSec > 0
        merged{1}.StartTimeSec = 0;
        merged{1}.DurationSec = merged{1}.EndTimeSec;
    end

    for k = 1:numel(merged)
        merged{k} = apply_segment_metrics(merged{k}, log, logStartTime);
    end

    segments = merged;
end

function segment = apply_segment_metrics(segment, log, logStartTime)
    absoluteStart = segment.StartTimeSec + logStartTime;
    absoluteEnd = segment.EndTimeSec + logStartTime;

    [avgSpeed, maxSpeed] = summarize_speed_window(log, absoluteStart, absoluteEnd);
    maxTurnRate = summarize_turn_rate_window(log, absoluteStart, absoluteEnd);

    if ~isnan(avgSpeed)
        segment.AvgSpeedMps = avgSpeed;
    end
    if ~isnan(maxSpeed)
        segment.MaxSpeedMps = maxSpeed;
    end
    if ~isnan(maxTurnRate)
        segment.MaxTurnRateRaw = maxTurnRate;
    end
end

function [avgSpeed, maxSpeed] = summarize_speed_window(log, startTime, endTime)
    avgSpeed = NaN;
    maxSpeed = NaN;

    candidates = {'GPS', 'THR'};
    fields = {'Spd', 'Speed'};
    for i = 1:numel(candidates)
        obj = get_field_value(log, candidates{i});
        if isempty(obj)
            continue;
        end
        values = get_field_value(obj, fields{i});
        times = get_field_value(obj, 'TimeS');
        if isempty(values) || isempty(times) || numel(values) ~= numel(times)
            continue;
        end

        values = double(values(:));
        times = double(times(:));
        mask = times >= startTime & times < endTime & isfinite(values);
        if any(mask)
            values = values(mask);
            avgSpeed = mean(values);
            maxSpeed = max(values);
            return;
        end
    end
end

function maxTurnRate = summarize_turn_rate_window(log, startTime, endTime)
    maxTurnRate = NaN;
    obj = get_field_value(log, 'STER');
    if isempty(obj)
        return;
    end

    values = get_field_value(obj, 'TurnRate');
    times = get_field_value(obj, 'TimeS');
    if isempty(values) || isempty(times) || numel(values) ~= numel(times)
        return;
    end

    values = double(values(:));
    times = double(times(:));
    mask = times >= startTime & times < endTime & isfinite(values);
    if any(mask)
        maxTurnRate = max(abs(values(mask)));
    end
end

function merged = merge_segment_group(group, preserveRepeatedModes)
    merged = group{1};
    merged.EndTimeSec = group{end}.EndTimeSec;
    merged.DurationSec = merged.EndTimeSec - merged.StartTimeSec;

    paramParts = {};
    modeParts = {};
    modeNames = {};
    for k = 1:numel(group)
        item = group{k};

        if ~isempty(item.ChangedParams)
            parts = strsplit(char(item.ChangedParams), '; ');
            for p = 1:numel(parts)
                part = strtrim(parts{p});
                if isempty(part) || any(strcmp(paramParts, part))
                    continue;
                end
                paramParts{end + 1} = part;
            end
        end

        if ~isempty(item.ModeSummary)
            parts = regexp(char(item.ModeSummary), '<br>|, ', 'split');
            for p = 1:numel(parts)
                part = strtrim(parts{p});
                if isempty(part)
                    continue;
                end
                modeParts{end + 1} = part;
                delimiter = strfind(part, ':');
                if isempty(delimiter)
                    modeName = part;
                else
                    modeName = strtrim(part(1:delimiter(1) - 1));
                end
                if ~any(strcmp(modeNames, modeName))
                    modeNames{end + 1} = modeName;
                end
            end
        end
    end

    if ~isempty(paramParts)
        merged.ChangedParams = strjoin(paramParts, '; ');
    else
        merged.ChangedParams = '';
    end

    if ~isempty(modeParts)
        if preserveRepeatedModes
            merged.ModeSummary = strjoin(modeParts, '<br>');
            modeNames = cellfun(@mode_name_from_summary_part, modeParts, 'UniformOutput', false);
            merged.MainMode = select_main_mode(modeNames);
            return;
        end

        modeDurations = containers.Map('KeyType', 'char', 'ValueType', 'double');
        for k = 1:numel(modeParts)
            part = modeParts{k};
            delimiter = strfind(part, ':');
            if isempty(delimiter)
                modeName = part;
                duration = 0;
            else
                modeName = strtrim(part(1:delimiter(1) - 1));
                durationText = strtrim(part(delimiter(1) + 1:end));
                durationText = strrep(durationText, 's', '');
                duration = str2double(durationText);
                if isnan(duration)
                    duration = 0;
                end
            end
            if isKey(modeDurations, modeName)
                modeDurations(modeName) = modeDurations(modeName) + duration;
            else
                modeDurations(modeName) = duration;
            end
        end

        durationKeys = keys(modeDurations);
        durationValues = cell2mat(values(modeDurations));
        [durationValues, order] = sort(durationValues, 'descend');
        summaryParts = cell(1, numel(order));
        for k = 1:numel(order)
            summaryParts{k} = sprintf('%s: %.1fs', durationKeys{order(k)}, durationValues(k));
        end
        merged.ModeSummary = strjoin(summaryParts, '<br>');
        merged.MainMode = durationKeys{order(1)};
        priorityModes = {'AUTO', 'RTL', 'ACRO'};
        for p = 1:numel(priorityModes)
            priorityIndex = find(strcmp(durationKeys, priorityModes{p}), 1);
            if ~isempty(priorityIndex) && modeDurations(durationKeys{priorityIndex}) > 0
                merged.MainMode = priorityModes{p};
                break;
            end
        end
    else
        merged.ModeSummary = '';
        merged.MainMode = 'UNKNOWN';
    end
end

function modeName = mode_name_from_summary_part(part)
    delimiter = strfind(part, ':');
    if isempty(delimiter)
        modeName = strtrim(part);
    else
        modeName = strtrim(part(1:delimiter(1) - 1));
    end
end

function mainMode = select_main_mode(modeNames)
    mainMode = modeNames{1};
    priorityModes = {'AUTO', 'RTL', 'ACRO'};
    for i = 1:numel(priorityModes)
        if any(strcmp(modeNames, priorityModes{i}))
            mainMode = priorityModes{i};
            return;
        end
    end
end

function info = summarize_mode_window(modeTimes, modeVals, startT, endT)
    info = struct('mainMode', 'UNKNOWN', 'summaryText', '');

    mask = modeTimes >= startT & modeTimes < endT;
    if ~any(mask)
        return;
    end

    t = modeTimes(mask);
    m = modeVals(mask);
    if isempty(t) || isempty(m)
        return;
    end

    [t, ord] = sort(t);
    m = m(ord);

    accum = containers.Map('KeyType', 'char', 'ValueType', 'double');
    startMode = m(1);
    startTime = t(1);

    for k = 2:numel(m)
        if m(k) ~= startMode
            key = mode_name_from_id(startMode);
            duration = t(k) - startTime;
            if duration < 0, duration = 0; end
            if isKey(accum, key)
                accum(key) = accum(key) + duration;
            else
                accum(key) = duration;
            end
            startMode = m(k);
            startTime = t(k);
        end
    end

    key = mode_name_from_id(startMode);
    duration = endT - startTime;
    if duration < 0, duration = 0; end
    if isKey(accum, key)
        accum(key) = accum(key) + duration;
    else
        accum(key) = duration;
    end

    keysList = keys(accum);
    valuesList = values(accum);
    durations = cell2mat(valuesList);
    keepMask = durations >= 0.1;
    keysList = keysList(keepMask);
    valuesList = valuesList(keepMask);
    durations = cell2mat(valuesList);

    if isempty(durations)
        return;
    end

    [sortedDur, ord2] = sort(durations, 'descend');
    summaryParts = {};
    for j = 1:numel(ord2)
        name = char(keysList(ord2(j)));
        summaryParts{end + 1} = sprintf('%s: %.1fs', name, sortedDur(j));
    end

    priorityModes = {'AUTO', 'RTL', 'ACRO'};
    info.mainMode = char(keysList(ord2(1)));
    for p = 1:numel(priorityModes)
        priorityIndex = find(strcmp(keysList, priorityModes{p}), 1);
        if ~isempty(priorityIndex) && durations(priorityIndex) > 0
            info.mainMode = priorityModes{p};
            break;
        end
    end
    info.summaryText = strjoin(summaryParts, '<br>');
end

function text = summarize_param_window(parmNamesRaw, parmValsRaw, parmTimes, startT, endT)
    text = '';
    if isempty(parmNamesRaw) || isempty(parmValsRaw) || isempty(parmTimes)
        return;
    end

    names = flatten_param_names(parmNamesRaw);
    values = flatten_param_values(parmValsRaw);
    n = min([numel(names), numel(values), numel(parmTimes)]);
    if n == 0
        return;
    end

    previous = containers.Map('KeyType', 'char', 'ValueType', 'any');
    parts = {};
    for k = 1:n
        timeVal = double(parmTimes(k));
        name = normalize_param_name(names{k});
        if isempty(name) || ~is_control_relevant_param(name)
            continue;
        end

        value = values{k};
        if isKey(previous, name)
            prevValue = previous(name);
            if timeVal >= startT && timeVal < endT && ~values_equal(prevValue, value)
                parts{end + 1} = sprintf('%s: %s -> %s', name, value_to_string(prevValue), value_to_string(value));
            end
        end

        previous(name) = value;
    end

    if isempty(parts)
        return;
    end

    text = strjoin(parts, '; ');
end

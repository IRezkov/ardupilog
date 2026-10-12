function modeInfo = summarize_modes(log)
    modeInfo = [];
    modeObj = get_field_value(log, 'MODE');
    if isempty(modeObj)
        return;
    end
    modeObj = clean_time_outliers(modeObj, 100, false);

    tRaw = get_field_value(modeObj, 'TimeS');
    mRaw = get_field_value(modeObj, 'Mode');
    if isempty(tRaw) || isempty(mRaw)
        return;
    end

    t = double(tRaw(:));
    m = double(mRaw(:));
    if isempty(t) || isempty(m) || numel(t) ~= numel(m)
        return;
    end
    keep = time_outlier_mask(t, 100);
    t = t(keep);
    m = m(keep);

    [t, ord] = sort(t);
    m = m(ord);
    accum = containers.Map('KeyType', 'char', 'ValueType', 'double');
    sessionEnd = compute_log_end_time(log);
    if isempty(sessionEnd)
        sessionEnd = t(end);
    end

    startMode = m(1);
    startTime = t(1);

    for k = 2:numel(m)
        if m(k) ~= startMode
            key = mode_name_from_id(startMode);
            duration = t(k) - startTime;
            if duration < 0
                duration = 0;
            end
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
    duration = sessionEnd - startTime;
    if duration < 0
        duration = 0;
    end
    if isKey(accum, key)
        accum(key) = accum(key) + duration;
    else
        accum(key) = duration;
    end

    keysList = keys(accum);
    valuesList = values(accum);
    durations = cell2mat(valuesList);

    if isempty(durations)
        modeInfo = [];
        return;
    end

    [sortedDur, ord2] = sort(durations, 'descend');

    summaryParts = {};
    for j = 1:numel(ord2)
        name = char(keysList(ord2(j)));
        summaryParts{end + 1} = sprintf('%s: %.1fs', name, sortedDur(j));
    end

    if isempty(summaryParts)
        return;
    end

    modeInfo.summaryText = strjoin(summaryParts, '<br>');
    modeInfo.mainMode = char(keysList(ord2(1)));
end
function startTime = extract_log_start_time(log, fullPath)
    startTime = [];
    if ~isempty(fullPath)
        candidate = basename_from_path(fullPath);
        startTime = parse_datetime_as_string(candidate);
        if ~isempty(startTime)
            return;
        end
    end

    if isempty(log)
        return;
    end

    bootTimeVal = get_field_value(log, 'bootTimeUTC');
    if ~isempty(bootTimeVal)
        startTime = char(string(bootTimeVal));
    end
end
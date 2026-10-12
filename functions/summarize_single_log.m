function rec = summarize_single_log(log, fullPath)
    rec = struct();
    rec.FileName = basename_from_path(fullPath);
    rec.FilePath = fullPath;
    rec.LogDir = fileparts(fullPath);

    % Извлекаем GPS время
    gpsTimeUTC = extract_gps_boot_time(log);
    
    if ~isempty(gpsTimeUTC)
        rec.BootTimeUTC = char(string(gpsTimeUTC));
    else
        % Если GPS время не найдено, используем текущее из имени файла
        startTimeVal = parse_datetime_as_string(basename_from_path(fullPath));
        if ~isempty(startTimeVal)
            rec.BootTimeUTC = char(string(startTimeVal));
        else
            rec.BootTimeUTC = '';
        end
    end

    rec.DurationSec = compute_duration(log);
    rec.MainMode = 'UNKNOWN';
    rec.ModeSummary = '';
    rec.AvgSpeedMps = NaN;
    rec.MaxSpeedMps = NaN;
    rec.MaxTurnRateRaw = NaN;
    rec.MaxThrottleOut = summarize_max_throttle_out_from_rec(rec, log);
    rec.ChangedParams = '';

    modeInfo = summarize_modes(log);
    if ~isempty(modeInfo)
        rec.MainMode = modeInfo.mainMode;
        rec.ModeSummary = modeInfo.summaryText;
    end

    [avgSpeed, maxSpeed] = summarize_speed(log);
    rec.AvgSpeedMps = avgSpeed;
    rec.MaxSpeedMps = maxSpeed;
    rec.MaxTurnRateRaw = summarize_turn_rate(log);
end
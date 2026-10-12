% Новая функция для извлечения GPS времени
function gpsTime = extract_gps_boot_time(log)
    gpsTime = [];
    gps = get_field_value(log, 'GPS');
    if isempty(gps)
        return;
    end
    
    % Ищем первый валидный GPS фикс
    validFix = false;
    if isprop(gps, 'Status')
        validFix = gps.Status >= 3;  % 3D fix
    end
    
    if isprop(gps, 'year') && isprop(gps, 'mth') && isprop(gps, 'day') && ...
       isprop(gps, 'h') && isprop(gps, 'min') && isprop(gps, 's')
        % Используем прямые поля даты/времени
        idx = find(validFix, 1, 'first');
        if isempty(idx)
            idx = 1;
        end
        gpsTime = datetime(gps.year(idx), gps.mth(idx), gps.day(idx), ...
                          gps.h(idx), gps.min(idx), gps.s(idx), 'TimeZone', 'UTC');
    else
        % Используем GPS неделю и миллисекунды
        if isprop(gps, 'GPSWeek') && isprop(gps, 'GMS')
            idx = find(validFix, 1, 'first');
            if isempty(idx)
                idx = 1;
            end
            week = gps.GPSWeek(idx);
            ms = gps.GMS(idx);
            gpsEpoch = datetime(1980, 1, 6, 0, 0, 0, 'TimeZone', 'UTC');
            gpsTime = gpsEpoch + seconds(week * 7 * 86400 + ms / 1000) - seconds(18);
        end
    end
end
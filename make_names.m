%% rename_bin_by_gps_with_prefix.m
% Переименование .bin логов ArduPilot:
%   Исходный: 00000011.BIN
%   Результат: log011_2026-09-01 14-39-34.bin
%
% Требования:
%   - библиотека ardupilog (https://github.com/Georacer/ardupilog)
%     должна быть добавлена в path MATLAB: addpath('путь/к/ardupilog')
%
clc
clear all

%% ========== Настройки ==========
LEAP_SECONDS = 18;
MIN_GPS_STATUS = 2;
USE_LOCAL_TIME = true;
LOCAL_TZ_OFFSET = 3;  % Москва UTC+3

%% ========== Выбор файла(ов) ==========
dirPath = pwd;
if ~exist('binFiles', 'var')
    [binFiles, dirPath] = uigetfile('*.bin', ...
        'Выберите .bin файл(ы) для переименования', ...
        'MultiSelect', 'on');
    if isequal(binFiles, 0)
        disp('Файл не выбран. Выход.');
        return;
    end
end

if ischar(binFiles)
    binFiles = {binFiles};
end
if isempty(dirPath)
    dirPath = fileparts(binFiles{1});
end

%% ========== Обработка ==========
for f = 1:numel(binFiles)
    [~, baseName, ext] = fileparts(binFiles{f});
    fullPath = fullfile(dirPath, binFiles{f});

    % --- Извлекаем первую последовательность цифр из имени ---
    digits = regexp(baseName, '\d+', 'match');
    if isempty(digits)
        warning('В имени "%s" нет цифр. Пропуск.', baseName);
        continue;
    end
    numStr = digits{1};

    % Преобразуем в число, чтобы убрать ведущие нули
    numVal = str2double(numStr);
    if isnan(numVal)
        warning('Не удалось распознать число в "%s". Пропуск.', numStr);
        continue;
    end

    % Форматируем минимум в 3 цифры: 11 -> 011, 5 -> 005, 123 -> 123
    prefixNum = sprintf('%03d', numVal);
    prefix = ['log' prefixNum '_'];

    try
        log = Ardupilog(fullPath, {'GPS'});
    catch ME
        warning('Не удалось прочитать %s: %s', binFiles{f}, ME.message);
        continue;
    end

    if ~isprop(log, 'GPS') || isempty(log.GPS.TimeS)
        warning('GPS-данные не найдены в %s. Пропуск.', binFiles{f});
        continue;
    end

    gps = log.GPS;
    utcTime = extractFirstGpsTime(gps, LEAP_SECONDS, MIN_GPS_STATUS);

    if USE_LOCAL_TIME
        utcTime = utcTime + hours(LOCAL_TZ_OFFSET);
    end

    timeStr = char(datetime(utcTime, 'Format', 'yyyy-MM-dd HH-mm-ss'));

    % Собираем новое имя: префикс + время + расширение
    newFilename = fullfile(dirPath, [prefix timeStr ext]);

    if strcmp(fullPath, newFilename)
        fprintf('Уже правильно назван: %s\n', binFiles{f});
        continue;
    end

    % Разрешение коллизий: если имя занято, добавляем _1, _2 и т.д.
    if exist(newFilename, 'file')
        suffix = 1;
        while exist(fullfile(dirPath, sprintf('%s%d%s', prefix, suffix, timeStr, ext)), 'file')
            suffix = suffix + 1;
        end
        newFilename = fullfile(dirPath, sprintf('%s%d_%s%s', prefix, suffix, timeStr, ext));
    end

    movefile(fullPath, newFilename);
    fprintf('Переименовано:\n  %s\n  -> %s\n\n', binFiles{f}, newFilename);
end


%% ========== Локальные функции ==========

function utcTime = extractFirstGpsTime(gps, leapSeconds, minStatus)
    if isprop(gps, 'I')
        mask = gps.I == 0;
    else
        mask = true(size(gps.TimeS));
    end

    if isprop(gps, 'Status')
        validMask = mask & (gps.Status >= minStatus);
        if ~any(validMask)
            warning('Нет GPS-фикса со статусом >= %d. Используется первая запись.', minStatus);
            validMask = mask;
        end
    else
        validMask = mask;
    end

    idx = find(validMask, 1, 'first');
    if isempty(idx)
        idx = 1;
    end

    if isprop(gps, 'year') && isprop(gps, 'mth') && isprop(gps, 'day') && ...
       isprop(gps, 'h') && isprop(gps, 'min') && isprop(gps, 's')
        utcTime = datetime(gps.year(idx), gps.mth(idx), gps.day(idx), ...
                          gps.h(idx), gps.min(idx), gps.s(idx));
        return;
    end

    wkField = ''; msField = '';
    if isprop(gps, 'GWk')
        wkField = 'GWk';
    elseif isprop(gps, 'GPSWeek')
        wkField = 'GPSWeek';
    elseif isprop(gps, 'GpsWk')
        wkField = 'GpsWk';
    end
    if isprop(gps, 'GMS')
        msField = 'GMS';
    elseif isprop(gps, 'GPSTime')
        msField = 'GPSTime';
    end

    if isempty(wkField) || isempty(msField)
        error('Не найдены поля GPS-времени (GWk/GMS или year/month/day/hour/min/sec).');
    end

    gpsWeek = gps.(wkField)(idx);
    gpsMs   = gps.(msField)(idx);

    if gpsWeek == 0 && gpsMs == 0
        warning('GPS-время равно нулю (нет спутников). Используется как есть.');
    end

    gpsEpoch = datetime(1980, 1, 6, 0, 0, 0, 'TimeZone', 'UTC');
    gpsTime  = gpsEpoch + seconds(double(gpsWeek) * 7 * 86400 + double(gpsMs) / 1000);
    utcTime  = gpsTime - seconds(leapSeconds);
end

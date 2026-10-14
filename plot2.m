% сначала проверим наличие папки functions
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
functionsDir = fullfile(scriptDir, 'functions');
if exist(functionsDir, 'dir')
    addpath(functionsDir);
else
    warning('Functions folder not found under %s', scriptDir);
end

selectedLogPath = '';
if exist('plot2SelectedLog', 'var') && ~isempty(plot2SelectedLog)
    selectedLogPath = plot2SelectedLog;
    clear plot2SelectedLog
end

reuseFigures = exist('plot2SignalFigure', 'var') && ...
    exist('plot2MapFigure', 'var') && ...
    isgraphics(plot2SignalFigure) && isgraphics(plot2MapFigure);
if reuseFigures
    signalFigure = plot2SignalFigure;
    mapFigure = plot2MapFigure;
    clear plot2SignalFigure plot2MapFigure
end

if ~exist('plot2ScriptPath', 'var') || isempty(plot2ScriptPath) || ...
        ~isfile(plot2ScriptPath)
    plot2ScriptPath = which('plot2.m');
end

clc
if isempty(selectedLogPath)
    selectedLogPath = select_plot2_log_file();
    if isempty(selectedLogPath)
        return;
    end
end
log = Ardupilog(selectedLogPath);
log = log.deleteEmptyMsgs;
if (ischar(log.filePathName) || ...
        (isstring(log.filePathName) && isscalar(log.filePathName))) && ...
        isfolder(log.filePathName)
    setpref('MissionPlannerPlot2', 'LastLogFolder', char(log.filePathName));
end
% log0=log.copy;

%%
% clc
% log=log0.copy;
clean_msg(log, 'MSG', 10, 1);
clean_msg(log, 'STER', 10, 1);
clean_msg(log, 'THR', 10, 1);


%% преобразуем
% clc
% name = log.fileName;
% name2 = [name(1:end-3) 'mat'];
% load([log.filePathName 'csv\' name2])

msg = [];
id = '';
if isprop(log, 'MSG') && ~isempty(log.MSG) && isprop(log.MSG, 'Message')
    msg = log.MSG.Message;
    if ~isempty(msg)
        id = strtrim(char(msg(1,:)));
    end
end
bootTimeUTC = log.bootTimeUTC;
bootTimeText = '';
if ~isempty(bootTimeUTC)
    bootTime = datetime(log.bootTimeUTC, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
    bootTime = bootTime + hours(3);
    bootTimeText = char(bootTime);
end

% Список имён режимов — так, чтобы индекс 1 соответствовал MANUAL=0
modesnames = [
    "MANUAL";
    "ACRO";
    "moment";          % 2 — пропущен в исходном enum
    "STEERING";
    "HOLD";
    "LOITER";
    "FOLLOW";
    "SIMPLE";
    "DOCK";
    "CIRCLE";
    "AUTO";
    "RTL";
    "SMART_RTL";
    "";    
    ""; % 13,14 — пропущены
    "GUIDED";
    "INITIALISING";
    "man angle"
];

[t0, logEndTime] = get_plot2_log_time_bounds(log);




%%
positionPreferenceGroup = 'MissionPlannerPlot2';

if reuseFigures
    zoom(signalFigure, 'off');
    pan(signalFigure, 'off');
    rotate3d(signalFigure, 'off');
    clf(signalFigure, 'reset');
else
    signalFigure = figure;
    mapFigure = [];
end
figure(signalFigure);
restore_saved_figure_position(signalFigure, 'SignalWindowPosition', positionPreferenceGroup);
signalFigure.CloseRequestFcn = @(src, ~) save_figure_position(src, 'SignalWindowPosition', positionPreferenceGroup);
title([bootTimeText ' ' id]);
signalAxes = signalFigure.CurrentAxes;
hold(signalAxes, 'on');
grid(signalAxes, 'on');
targetTrajectory = build_target_trajectory(log, t0);
signalCatalog = build_plot2_signal_catalog(log, targetTrajectory);
signalProfiles = load_plot2_signal_profiles();
activeProfileName = 'Main';
if ispref('MissionPlannerPlot2', 'ActiveSignalProfile')
    activeProfileName = getpref('MissionPlannerPlot2', 'ActiveSignalProfile');
end
activeProfileIndex = find(strcmp({signalProfiles.name}, activeProfileName), 1);
if isempty(activeProfileIndex)
    activeProfileIndex = find(strcmp({signalProfiles.name}, 'Main'), 1);
    if isempty(activeProfileIndex)
        activeProfileIndex = 1;
    end
end
activeProfile = signalProfiles(activeProfileIndex);
lgd = legend(signalAxes, 'show');
[h, unavailableSignalIds] = apply_plot2_signal_profile( ...
    signalFigure, signalAxes, lgd, log, signalCatalog, ...
    activeProfile.signalIds, t0, targetTrajectory);
signalFigure.UserData.plot2ProfileName = activeProfile.name;
signalFigure.UserData.plot2ProfileSignals = activeProfile.signalIds;
signalFigure.UserData.plot2UnavailableSignals = unavailableSignalIds;
title(log.fileName,'interpreter','none');

signalAxes.Units = 'normalized';
lgd.Units = 'normalized';
lgd.Location = 'none';
fixedAxesPosition = get(signalAxes, 'Position');
signalAxes.UserData.FixedPosition = fixedAxesPosition;
lgd.UserData.FixedAxesPosition = fixedAxesPosition;
lgd.UserData.FixedPosition = get(lgd, 'Position');
lgd.Position = lgd.UserData.FixedPosition;

% Линии режимов и сообщения не зависят от выбранного профиля.
if isprop(log, 'MODE') && ~isempty(log.MODE) && ...
        isprop(log.MODE, 'TimeS') && isprop(log.MODE, 'Mode')
    modeLineCount = min(numel(log.MODE.TimeS), numel(log.MODE.Mode));
    for i = 1:modeLineCount
        line([log.MODE.TimeS(i) log.MODE.TimeS(i)] - t0, [0 50], ...
            'Color', 'black', 'HandleVisibility', 'off');
        modeIndex = double(log.MODE.Mode(i)) + 1;
        if isfinite(modeIndex) && modeIndex >= 1 && modeIndex <= numel(modesnames)
            modeText = modesnames(modeIndex);
        else
            modeText = "UNKNOWN";
        end
        text(log.MODE.TimeS(i) - t0, 20 + i * 2, modeText);
    end
end
if ~isempty(msg) && isprop(log.MSG, 'TimeS')
    messageCount = min(numel(log.MSG.TimeS), size(msg, 1));
    for i = 1:messageCount
        y = mod(i * 5, 250) + 50;
        line([log.MSG.TimeS(i) log.MSG.TimeS(i)] - t0, [0 y], ...
            'Color', 'black', 'HandleVisibility', 'off');
        text(log.MSG.TimeS(i) - t0, y, msg(i,:));
    end
end

% xlim([0 2000]);
% ylim([-100 300]);
grid on

% --- Выпадающий список режимов с автозумом ---
modeTimes = [];
modeNums = [];
modeLabels = strings(0, 1);
durations = [];
if isprop(log, 'MODE') && ~isempty(log.MODE) && ...
        isprop(log.MODE, 'TimeS') && isprop(log.MODE, 'Mode')
    modeCount = min(numel(log.MODE.TimeS), numel(log.MODE.Mode));
    modeTimes = double(log.MODE.TimeS(1:modeCount)) - t0;
    modeNums = double(log.MODE.Mode(1:modeCount));
    if ~isempty(modeTimes)
        tEnd = logEndTime - t0;
        durations = [diff(modeTimes); max(0, tEnd - modeTimes(end))];
        modeLabels = strings(numel(modeNums), 1);
        for i = 1:numel(modeNums)
            modeIndex = modeNums(i) + 1;
            if isfinite(modeIndex) && modeIndex >= 1 && modeIndex <= numel(modesnames)
                modeName = modesnames(modeIndex);
            else
                modeName = "UNKNOWN";
            end
            modeLabels(i) = sprintf('#%d  %s  %.1f s  (t=%.1f)', ...
                i, modeName, durations(i), modeTimes(i));
        end
    end
end

if isempty(modeLabels)
    uic = uicontrol('Style', 'popup', 'Units', 'normalized', ...
        'String', {'No modes'}, 'Position', [0.01, 0.95, 0.30, 0.035], ...
        'FontSize', 9, 'Enable', 'off');
else
    uic = uicontrol('Style', 'popup', ...
        'Units', 'normalized', ...
        'String', cellstr(modeLabels), ...
        'Position', [0.01, 0.95, 0.30, 0.035], ...
        'FontSize', 9, ...
        'Callback', @(src, ev) zoomToMode(src, ev, modeTimes, durations));
end


% карта
% try
    % clc
hasGPS = isprop(log, 'GPS') && ~isempty(log.GPS);
if hasGPS
    gpsGroup = log.GPS;
    hasGpsCoordinates = isprop(gpsGroup, 'Lat') && isprop(gpsGroup, 'Lng') && ...
        ~isempty(gpsGroup.Lat) && ~isempty(gpsGroup.Lng);
    if hasGpsCoordinates && ~isprop(gpsGroup, 'Status')
        warning('plot2:GPSStatusUnavailable', ...
            'В логе нет GPS.Status; качество GPS-фикса проверить нельзя, карта пропущена.');
    elseif hasGpsCoordinates && ...
            (~isprop(gpsGroup, 'TimeS') || ~isprop(gpsGroup, 'Spd'))
        warning('plot2:GPSFieldsUnavailable', ...
            'В логе отсутствуют поля GPS.TimeS или GPS.Spd; карта пропущена.');
    end
    hasGPS = hasGpsCoordinates && all([ ...
        isprop(gpsGroup, 'Status'), isprop(gpsGroup, 'TimeS'), ...
        isprop(gpsGroup, 'Spd')]);
end
if hasGPS
    gpsPositionCount = min([numel(gpsGroup.Lat), numel(gpsGroup.Lng), ...
        numel(gpsGroup.Status), numel(gpsGroup.TimeS), numel(gpsGroup.Spd)]);
    gpsLat = double(gpsGroup.Lat(1:gpsPositionCount));
    gpsLng = double(gpsGroup.Lng(1:gpsPositionCount));
    gpsStatus = double(gpsGroup.Status(1:gpsPositionCount));
    gpsTimeS = double(gpsGroup.TimeS(1:gpsPositionCount)) - t0;
    gpsSpeed = double(gpsGroup.Spd(1:gpsPositionCount)) * 3.6;
    gpsValidMask = isfinite(gpsLat) & isfinite(gpsLng) & ...
        abs(gpsLat) <= 90 & abs(gpsLng) <= 180 & ...
        isfinite(gpsStatus) & gpsStatus >= 3;
    hasGPS = gpsPositionCount > 0 && any(gpsValidMask);
    gpsLat(~gpsValidMask) = NaN;
    gpsLng(~gpsValidMask) = NaN;
end

if hasGPS
    fprintf('GPS точек: %d\n', numel(log.GPS.Lat));

    % % arcgisonline
    % url = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/${z}/${y}/${x}';
    % 
    % addCustomBasemap('esriSat', url, ...
    %     'Attribution', '© Esri', ...
    %     'DisplayName', 'ESRI Satellite');
    
    if reuseFigures
        clf(mapFigure, 'reset');
    else
        mapFigure = figure;
    end
    figure(mapFigure);
    restore_saved_figure_position(mapFigure, 'MapWindowPosition', positionPreferenceGroup);
    mapFigure.CloseRequestFcn = @(src, ~) save_figure_position(src, 'MapWindowPosition', positionPreferenceGroup);
    % gax = geoaxes('Basemap', 'esriSat');
    gax = geoaxes('Basemap', 'Satellite');
    title(log.fileName,'interpreter','none');

    % --- Точки миссии на карте ---
    if isprop(log, 'WP')
        wpLat = log.WP.Lat(:);
        wpLng = log.WP.Lng(:);
        wpNum = log.WP.Num(:);
    elseif isprop(log, 'MISE')
        wpLat = log.MISE.Lat(:);
        wpLng = log.MISE.Lng(:);
        wpNum = log.MISE.CNum(:);
    else
        wpLat = []; wpLng = []; wpNum = [];
        fprintf('В логе нет WP или MISE — точки миссии не найдены\n');
    end
    
    if ~isempty(wpLat)
        % Оставляем только уникальные точки (MISE может дублировать)
        [~, uniqIdx] = unique([wpLat, wpLng], 'rows', 'stable');
        wpLat = wpLat(uniqIdx);
        wpLng = wpLng(uniqIdx);
        wpNum = wpNum(uniqIdx);
    
        % Линии между точками
        hold(gax, 'on');
        geoplot(gax, wpLat, wpLng, 'w--', 'LineWidth', 3, 'HandleVisibility', 'off');
    
        % Маркеры + номера
        geoscatter(gax, wpLat, wpLng, 40, 'w', 'filled', 'HandleVisibility', 'off');
        for i = 1:numel(wpLat)
            text(gax, wpLat(i), wpLng(i), sprintf(' %d', wpNum(i)), ...
                'Color', 'white', 'FontSize', 14, 'HandleVisibility', 'off');
        end
        fprintf('Точек миссии: %d\n', numel(wpLat));
    end


    % gp = geoplot(log.GPS.Lat, log.GPS.Lng, 'LineWidth', 1.5);
    gp = geoscatter(gax, gpsLat, gpsLng, 10, [0.45 0.25 0.75], 'filled');
    hold(gax, 'on');

    
    % Отсечение выбросов
    gpsSpeed(gpsSpeed > 150) = NaN;
    gpsSpeed(isinf(gpsSpeed)) = NaN;




    


    % Привязываем карту и GPS-данные к выпадающему списку
    uic.UserData.gax      = gax;
    uic.UserData.gp       = gp;
    uic.UserData.gpsTimeS = gpsTimeS;
    uic.UserData.gpsLat   = gpsLat;
    uic.UserData.gpsLng   = gpsLng;
    uic.UserData.gpsSpeed = gpsSpeed;
    uic.UserData.ekfTimeS = [];
    uic.UserData.ekfLat   = [];
    uic.UserData.ekfLng   = [];
    uic.UserData.ekfTrack = gobjects(0);
    uic.UserData.ekfStart = gobjects(0);
    uic.UserData.ekfEnd   = gobjects(0);
    
    % colorbar для шкалы скорости EKF
    cb = colorbar(gax);
    cb.Label.String = 'Скорость, км/ч';
    cb.Label.FontSize = 9;
    colormap(gax, jet);
    caxis(gax, [0 1]);

    uic.UserData.cb = cb;   % <-- добавь эту строку
    signalFigure.UserData.mapAxes = gax;
    signalFigure.UserData.gpsTimeS = gpsTimeS;
    signalFigure.UserData.gpsLat = gpsLat;
    signalFigure.UserData.gpsLng = gpsLng;
    signalFigure.UserData.boatMarker = gobjects(0);
    signalFigure.UserData.boatActuators = build_plot2_boat_actuators(log, t0);
    
% catch
%     % googleSat
%     url = 'https://mt0.google.com/vt/lyrs=s&x=${x}&y=${y}&z=${z}';
% 
%     addCustomBasemap('googleSat', url, ...
%         'Attribution', '© Google', ...
%         'DisplayName', 'Google Satellite');
% 
%     figure
%     geoaxes('Basemap', 'googleSat');
%     geoplot(log.GPS.Lat,log.GPS.Lng)
% end







% 1. Сохраняем опорные точки в UserData осей
firstGoodGpsIndex = find(gpsValidMask, 1, 'first');
gax.UserData.refLat = gpsLat(firstGoodGpsIndex);
gax.UserData.refLng = gpsLng(firstGoodGpsIndex);
gax.UserData.prevLatTicks = [];  % <-- добавить
gax.UserData.prevLonTicks = [];  % <-- добавить

% 2. Первичная отрисовка
updateMeterLabels(gax, gax.UserData.refLat, gax.UserData.refLng);

% 3. Слушаем MarkedClean на ЛИНЕЙКАХ (rulers), а не на осях или фигуре
hLatListener = addlistener(gax.LatitudeAxis, 'MarkedClean', @(~,~) onRulerClean(gax));
hLonListener = addlistener(gax.LongitudeAxis, 'MarkedClean', @(~,~) onRulerClean(gax));

% 4. Сохраняем слушателей, чтобы сборщик мусора их не удалил
gax.UserData.hLatListener = hLatListener;
gax.UserData.hLonListener = hLonListener;
else
    fprintf('Нет GPS-координат с подтвержденным 3D-фиксом. Карта GPS и EKF пропущена.\n');
    if reuseFigures
        clf(mapFigure, 'reset');
    else
        mapFigure = figure;
    end
    figure(mapFigure);
    restore_saved_figure_position(mapFigure, 'MapWindowPosition', positionPreferenceGroup);
    mapFigure.CloseRequestFcn = @(src, ~) save_figure_position( ...
        src, 'MapWindowPosition', positionPreferenceGroup);
    [localEkfTrack, hasLocalEkfTrack] = build_plot2_local_ekf_track(log);
    localAxes = axes('Parent', mapFigure);
    if hasLocalEkfTrack
        plot(localAxes, localEkfTrack.east, localEkfTrack.north, ...
            'Color', [0.1 0.4 0.75], 'LineWidth', 1.2, ...
            'DisplayName', 'EKF trajectory');
        hold(localAxes, 'on');
        plot(localAxes, localEkfTrack.east(1), localEkfTrack.north(1), ...
            'o', 'Color', [0.1 0.6 0.2], 'MarkerFaceColor', [0.1 0.6 0.2], ...
            'DisplayName', 'Start');
        plot(localAxes, localEkfTrack.east(end), localEkfTrack.north(end), ...
            's', 'Color', [0.8 0.2 0.2], 'MarkerFaceColor', [0.8 0.2 0.2], ...
            'DisplayName', 'End');
        axis(localAxes, 'equal');
        grid(localAxes, 'on');
        xlabel(localAxes, 'East (PE), m');
        ylabel(localAxes, 'North (PN), m');
        title(localAxes, [log.fileName ' - local EKF position'], ...
            'interpreter', 'none');
        legend(localAxes, 'show', 'Location', 'best');
    else
        axis(localAxes, 'off');
        title(localAxes, log.fileName, 'interpreter', 'none');
        text(localAxes, 0.5, 0.5, ...
            'GPS and local EKF position data unavailable', ...
            'HorizontalAlignment', 'center', 'Units', 'normalized');
    end

    gpsLat = [];
    gpsLng = [];
    gpsTimeS = [];
    gpsSpeed = [];
    uic.UserData.gp = gobjects(0);
    uic.UserData.gpsTimeS = [];
    uic.UserData.gpsLat = [];
    uic.UserData.gpsLng = [];
    uic.UserData.gpsSpeed = [];
    uic.UserData.ekfTimeS = [];
    uic.UserData.ekfLat = [];
    uic.UserData.ekfLng = [];
    uic.UserData.ekfSpeed = [];
    uic.UserData.ekfTrack = gobjects(0);
    uic.UserData.ekfStart = gobjects(0);
    uic.UserData.ekfEnd = gobjects(0);
    signalFigure.UserData.gpsTimeS = [];
    signalFigure.UserData.gpsLat = [];
    signalFigure.UserData.gpsLng = [];
    signalFigure.UserData.boatMarker = gobjects(0);
end




% Добавляем трек EKF на существующую карту (gax)

% EKF-карта необязательна для профиля сигналов.
hasOrigin = isprop(log, 'ORGN') && ~isempty(log.ORGN) && ...
    isprop(log.ORGN, 'Lat') && isprop(log.ORGN, 'Lng') && ...
    ~isempty(log.ORGN.Lat) && ~isempty(log.ORGN.Lng);
if ~hasGPS
    % The local EKF path, when available, is shown in the no-GPS window.
elseif ~hasOrigin
    warning('В логе нет данных ORGN. Отрисовка EKF невозможна.');
elseif ~isprop(log, 'XKF1') || isempty(log.XKF1)
    warning('В логе нет данных XKF1. Отрисовка EKF невозможна.');
else
    orgn = log.ORGN;
    refLat = orgn.Lat(1);
    refLon = orgn.Lng(1);
    xkf = log.XKF1;
    
    % Проверка на наличие данных
    if isempty(xkf.PN) || isempty(xkf.PE)
        warning('Данные XKF1 пусты. Пропускаем отрисовку EKF.');
    else
        % 3. Конвертация PN/PE (метры) → глобальные координаты (градусы)
        degToM = 111319.9;
        cosRefLat = cosd(refLat);
        
        ekfLat = refLat + xkf.PN / degToM;
        ekfLon = refLon + xkf.PE / (degToM * cosRefLat);
        
        % Удаляем NaN из данных, чтобы не ломать линию (опционально, но рекомендуется)
        validIdx = ~(isnan(ekfLat) | isnan(ekfLon));
        ekfTimeS = xkf.TimeS(validIdx) - t0;
        ekfLat = ekfLat(validIdx);
        ekfLon = ekfLon(validIdx);
        ekfSpeed = [];
        if isprop(xkf, 'VN') && isprop(xkf, 'VE')
            ekfSpeed = hypot(double(xkf.VN(validIdx)), double(xkf.VE(validIdx))) * 3.6;
        end
        if isempty(ekfSpeed)
            ekfSpeed = nan(size(ekfLat));
        end
        uic.UserData.ekfTimeS = ekfTimeS(:);
        uic.UserData.ekfLat = ekfLat(:);
        uic.UserData.ekfLng = ekfLon(:);
        uic.UserData.ekfSpeed = ekfSpeed(:);
        
        if numel(ekfLat) > 1
            % 4. Рисуем на ТОЙ ЖЕ фигуре и осях (gax), которые были созданы выше!
            % Не делай gax = geoaxes() заново!
            % gax = geoaxes('Basemap', 'Satellite'); %тест
            % hold(gax, 'on');
            
            uic.UserData.ekfTrack = geoscatter(gax, ekfLat, ekfLon, 10, ekfSpeed, 'filled');
            
            % Если хочешь добавить маркеры в начале/конце
            uic.UserData.ekfStart = geoscatter(gax, ekfLat(1), ekfLon(1), 50, 'w', 'filled'); % Старт - белый
            uic.UserData.ekfEnd = geoscatter(gax, ekfLat(end), ekfLon(end), 50, 'g', 'filled'); % Конец - зелёный
            uistack([uic.UserData.ekfTrack, uic.UserData.ekfStart, uic.UserData.ekfEnd], 'top');
            
            fprintf('Отрисован трек EKF (%d точек).\n', numel(ekfLat));
        else
            warning('Недостаточно валидных точек EKF для отрисовки линии.');
        end
    end
end

if isfield(uic.UserData, 'ekfSpeed')
    validEkfSpeed = uic.UserData.ekfSpeed(isfinite(uic.UserData.ekfSpeed));
    if ~isempty(validEkfSpeed)
        caxis(gax, [0 max(1, 1.1 * max(validEkfSpeed))]);
    end
end

signalFigure.UserData.ekfTimeS = uic.UserData.ekfTimeS;
signalFigure.UserData.ekfLat = uic.UserData.ekfLat;
signalFigure.UserData.ekfLng = uic.UserData.ekfLng;
signalFigure.UserData.modeTimes = modeTimes;
signalFigure.UserData.modeNums = modeNums;

uicontrol(signalFigure, 'Style', 'pushbutton', ...
    'String', 'Open log', ...
    'Units', 'normalized', ...
    'Position', [0.0 0.85 0.08 0.04], ...
    'FontSize', 9, ...
    'Callback', @(~, ~) choose_and_open_log(signalFigure, mapFigure, plot2ScriptPath));
uicontrol(signalFigure, 'Style', 'pushbutton', ...
    'String', 'Save mini-report', ...
    'Units', 'normalized', ...
    'Position', [0.0 0.805 0.08 0.04], ...
    'FontSize', 9, ...
    'Callback', @(~, ~) save_mini_report_for_current_mode( ...
        signalFigure, mapFigure, log, pwd, uic, modeLabels, modeTimes, t0));
uic.UserData.signalFigure = signalFigure;

if ~isempty(targetTrajectory.time) && isfield(uic.UserData, 'gax')
    targetTrajectory.axes = signalAxes;
    targetTrajectory.mapAxes = gax;
    targetTrajectory.targetTrack = geoplot(gax, ...
        targetTrajectory.originLat + targetTrajectory.targetNorth / targetTrajectory.metersPerDegree, ...
        targetTrajectory.originLon + targetTrajectory.targetEast / ...
        (targetTrajectory.metersPerDegree * cosd(targetTrajectory.originLat)), ...
        'Color', 'yellow', 'LineWidth', 2, 'DisplayName', 'Target trajectory');
    targetTrajectory.targetMarker = gobjects(0);
    targetTrajectory.targetLabel = gobjects(0);
    targetTrajectory.boatMarker = gobjects(0);
    targetTrajectory.targetVector = gobjects(0);
    targetTrajectory.currentTime = NaN;
    targetTrajectory.currentNorth = NaN;
    targetTrajectory.currentEast = NaN;
    targetTrajectory.currentLat = NaN;
    targetTrajectory.currentLon = NaN;
    signalFigure.UserData.targetTrajectory = targetTrajectory;
end

uicontrol(signalFigure, 'Style', 'pushbutton', ...
    'String', 'Signal profiles', ...
    'Tag', 'Plot2OpenSignalProfiles', ...
    'Units', 'normalized', ...
    'Position', [0.0 0.905 0.15 0.04], ...
    'FontSize', 9, ...
    'Callback', @(~, ~) open_plot2_signal_profile_editor( ...
        signalFigure, signalAxes, lgd, log, signalCatalog, t0, targetTrajectory));

signalFigure.UserData.cursorTool = struct( ...
    'axes', signalAxes, 'legend', lgd, 'cursorLine', gobjects(0), ...
    'currentTime', NaN, 'enabled', false, 'dragging', false, ...
    'lastLegendUpdate', -Inf);
uic.UserData.xLimListener = addlistener(signalAxes, 'XLim', 'PostSet', ...
    @(~, ~) sync_map_to_time_window(signalAxes, uic));
signalFigure.WindowButtonDownFcn = @(src, ~) set_cursor_from_click(src);
cursorToggle = uicontrol(signalFigure, 'Style', 'togglebutton', ...
    'String', 'Cursor: OFF', ...
    'Units', 'normalized', ...
    'Position', [0.17 0.905 0.10 0.04], ...
    'FontSize', 9, ...
    'Callback', @(src, event) toggle_cursor_tool(src, event, signalFigure));
signalFigure.UserData.cursorToggle = cursorToggle;

function set_plot2_speed_unit(src, ~, uic)
units = {'km/h', 'm/s'};
unitName = units{src.Value};

uic.UserData.speedUnit = unitName;
ud = uic.UserData;

if isfield(ud, 'ekfTimeS') && ~isempty(ud.ekfTimeS) && ...
        isfield(ud, 'ekfSpeed') && ~isempty(ud.ekfSpeed)
    speedForMap = convert_speed_for_unit(ud.ekfSpeed, unitName);
    if isfield(ud, 'ekfTrack') && ~isempty(ud.ekfTrack) && isgraphics(ud.ekfTrack)
        ud.ekfTrack.CData = speedForMap;
        finiteSpeed = speedForMap(isfinite(speedForMap));
        if ~isempty(finiteSpeed)
            speedMin = min(finiteSpeed);
            speedMax = max(finiteSpeed);
            padding = max(0.1 * (speedMax - speedMin), max(abs(speedMin) * 0.1, 1));
            if speedMin == speedMax
                padding = max(abs(speedMin) * 0.1, 1);
            end
            clim(ud.gax, [speedMin - padding, speedMax + padding]);
        end
    end
end

if isfield(ud, 'cb') && isgraphics(ud.cb)
    ud.cb.Label.String = speed_unit_label(unitName);
end
uic.UserData = ud;
end

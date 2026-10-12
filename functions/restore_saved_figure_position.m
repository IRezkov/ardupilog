function restore_saved_figure_position(fig, key, preferenceGroup)
    if nargin < 3 || isempty(preferenceGroup)
        preferenceGroup = 'MissionPlannerPlot2';
    end

    position = [];
    if ispref(preferenceGroup, key)
        position = getpref(preferenceGroup, key);
    end

    if isempty(position) || numel(position) ~= 4 || any(~isfinite(position))
        return;
    end

    fig.Position = clamp_figure_position(position);
end

function position = clamp_figure_position(position)
    monitors = get(0, 'MonitorPositions');
    if isempty(monitors)
        monitors = get(0, 'ScreenSize');
    end

    width = min(position(3), max(monitors(:, 3)));
    height = min(position(4), max(monitors(:, 4)));

    monitorIndex = find(position(1) >= monitors(:, 1) & ...
        position(1) < monitors(:, 1) + monitors(:, 3) - monitors(:, 1), 1);
    if isempty(monitorIndex)
        monitorIndex = 1;
    end

    monitor = monitors(monitorIndex, :);
    x = min(max(position(1), monitor(1)), monitor(1) + monitor(3) - width);
    y = min(max(position(2), monitor(2)), monitor(2) + monitor(4) - height);
    position = [x y width height];
end

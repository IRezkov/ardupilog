function save_figure_position(fig, key, preferenceGroup)
    if nargin < 3 || isempty(preferenceGroup)
        preferenceGroup = 'MissionPlannerPlot2';
    end
    if isempty(fig) || ~isvalid(fig)
        return;
    end

    setpref(preferenceGroup, key, fig.Position);
    delete(fig);
end

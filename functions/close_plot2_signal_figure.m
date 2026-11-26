function close_plot2_signal_figure(signalFigure, preferenceKey, preferenceGroup)
%CLOSE_PLOT2_SIGNAL_FIGURE Save current profile state and close the signal figure.

if isempty(signalFigure) || ~isgraphics(signalFigure)
    return;
end
save_plot2_signal_profile_state(signalFigure);
if isstruct(signalFigure.UserData) && ...
        isfield(signalFigure.UserData, 'plot2ComparisonAxes') && ...
        isgraphics(signalFigure.UserData.plot2ComparisonAxes)
    save_plot2_signal_profile_state( ...
        signalFigure, true, signalFigure.UserData.plot2ComparisonAxes);
end
save_figure_position(signalFigure, preferenceKey, preferenceGroup);
end

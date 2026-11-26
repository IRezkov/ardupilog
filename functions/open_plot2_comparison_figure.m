function comparisonAxes = open_plot2_comparison_figure( ...
    signalFigure, logObj, catalog, t0, targetTrajectory, profileState, openEditor)
%OPEN_PLOT2_COMPARISON_FIGURE Add a second signal subplot to the main figure.

if nargin < 6
    profileState = [];
end
if nargin < 7
    openEditor = false;
end
if isempty(signalFigure) || ~isgraphics(signalFigure) || ...
        ~isstruct(signalFigure.UserData) || ...
        ~isfield(signalFigure.UserData, 'cursorTool')
    error('plot2:ComparisonPlotUnavailable', ...
        'The main signal plot is not ready for a comparison subplot.');
end

figureData = signalFigure.UserData;
if isfield(figureData, 'plot2ComparisonAxes') && ...
        isgraphics(figureData.plot2ComparisonAxes) && isempty(profileState)
    comparisonAxes = figureData.plot2ComparisonAxes;
    if openEditor
        open_plot2_signal_profile_editor( ...
            signalFigure, comparisonAxes, figureData.plot2ComparisonLegend, ...
            logObj, catalog, t0, targetTrajectory);
    end
    return;
end

mainAxes = figureData.cursorTool.axes;
mainLegend = figureData.cursorTool.legend;
mainAxesPosition = [0.07 0.50 0.65 0.32];
comparisonAxesPosition = [0.07 0.11 0.65 0.34];

mainAxes.Units = 'normalized';
mainAxes.Position = mainAxesPosition;
mainAxes.UserData.FixedPosition = mainAxesPosition;
mainLegend.Units = 'normalized';
mainLegend.Location = 'none';
mainLegend.UserData.FixedAxesPosition = mainAxesPosition;

if isempty(profileState)
    profileName = 'Comparison';
    signalIds = {};
    lineScaleSettings = struct( ...
        'signalId', {}, 'scaleMode', {}, 'scaleFactor', {});
    highlightedSignalIds = {};
else
    profileName = profileState.name;
    signalIds = profileState.signalIds;
    lineScaleSettings = profileState.lineScaleSettings;
    highlightedSignalIds = profileState.highlightedSignalIds;
end

comparisonAxes = axes('Parent', signalFigure, ...
    'Units', 'normalized', 'Position', comparisonAxesPosition);
hold(comparisonAxes, 'on');
grid(comparisonAxes, 'on');
comparisonAxes.UserData.FixedPosition = comparisonAxesPosition;
comparisonLegend = legend(comparisonAxes, 'show');
comparisonLegend.Units = 'normalized';
comparisonLegend.Location = 'none';
comparisonLegend.UserData.FixedAxesPosition = comparisonAxesPosition;

figureData.plot2ComparisonAxes = comparisonAxes;
figureData.plot2ComparisonProfileName = profileName;
figureData.plot2ComparisonProfileSignals = signalIds;
figureData.plot2ComparisonProfileLines = gobjects(0);
figureData.plot2ComparisonLegend = comparisonLegend;
figureData.cursorTool.comparisonAxes = comparisonAxes;
figureData.cursorTool.comparisonLegend = comparisonLegend;
figureData.cursorTool.comparisonCursorLine = gobjects(0);
signalFigure.UserData = figureData;

[~, unavailableSignalIds, comparisonLegend] = apply_plot2_signal_profile( ...
    signalFigure, comparisonAxes, comparisonLegend, logObj, catalog, ...
    signalIds, t0, targetTrajectory);
signalFigure.UserData.plot2ComparisonLegend = comparisonLegend;
signalFigure.UserData.plot2ComparisonUnavailableSignals = unavailableSignalIds;
profile = struct('lineScaleSettings', {lineScaleSettings}, ...
    'highlightedSignalIds', {highlightedSignalIds});
restore_plot2_signal_profile_state(comparisonLegend, profile);
title(comparisonAxes, [logObj.fileName ' - Plot 2'], 'Interpreter', 'none');
xlabel(comparisonAxes, 'Time, s');

legendX = 0.75;
mainAxes.Position = mainAxesPosition;
mainAxes.UserData.FixedPosition = mainAxesPosition;
comparisonAxes.Position = comparisonAxesPosition;
comparisonAxes.UserData.FixedPosition = comparisonAxesPosition;
mainLegend.UserData.FixedAxesPosition = mainAxesPosition;
comparisonLegend.UserData.FixedAxesPosition = comparisonAxesPosition;
mainLegendPosition = mainLegend.Position;
mainLegendPosition(1) = legendX;
mainLegendPosition(2) = mainAxesPosition(2) + ...
    (mainAxesPosition(4) - mainLegendPosition(4)) / 2;
mainLegend.Position = mainLegendPosition;
mainLegend.UserData.FixedPosition = mainLegendPosition;
comparisonLegendPosition = comparisonLegend.Position;
comparisonLegendPosition(1) = legendX;
comparisonLegendPosition(2) = comparisonAxesPosition(2) + ...
    (comparisonAxesPosition(4) - comparisonLegendPosition(4)) / 2;
comparisonLegend.Position = comparisonLegendPosition;
comparisonLegend.UserData.FixedPosition = comparisonLegendPosition;

xlim(comparisonAxes, xlim(mainAxes));
linkaxes([mainAxes comparisonAxes], 'x');
if openEditor
    open_plot2_signal_profile_editor( ...
        signalFigure, comparisonAxes, comparisonLegend, logObj, ...
        catalog, t0, targetTrajectory);
end

if signalFigure.UserData.cursorTool.enabled
    cursorTime = signalFigure.UserData.cursorTool.currentTime;
    if ~isfinite(cursorTime)
        cursorTime = mean(xlim(mainAxes));
    end
    update_cursor_tool(signalFigure, cursorTime);
end
end

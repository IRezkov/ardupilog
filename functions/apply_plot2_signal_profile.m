function [lineHandles, unavailableIds] = apply_plot2_signal_profile( ...
    signalFigure, signalAxes, legendHandle, logObj, catalog, signalIds, ...
    t0, targetTrajectory)
%APPLY_PLOT2_SIGNAL_PROFILE Replace plotted signals and refresh legend handles.

if isfield(signalFigure.UserData, 'plot2ProfileLines')
    oldLines = signalFigure.UserData.plot2ProfileLines;
    oldLines = oldLines(isgraphics(oldLines));
    if ~isempty(oldLines)
        delete(oldLines);
    end
end

hold(signalAxes, 'on');
[lineHandles, unavailableIds] = render_plot2_signal_profile( ...
    signalAxes, logObj, catalog, signalIds, t0, targetTrajectory);

lineNames = cell(1, numel(lineHandles));
for lineIndex = 1:numel(lineHandles)
    lineHandles(lineIndex).UserData.OrigLineWidth = lineHandles(lineIndex).LineWidth;
    lineHandles(lineIndex).UserData.OrigColor = lineHandles(lineIndex).Color;
    lineHandles(lineIndex).UserData.BaseDisplayName = lineHandles(lineIndex).DisplayName;
    lineNames{lineIndex} = lineHandles(lineIndex).DisplayName;
end

if isempty(lineHandles)
    legendHandle.String = {};
    legendHandle.Visible = 'off';
else
    legendHandle = legend(signalAxes, lineHandles, lineNames);
    legendHandle.Visible = 'on';
end
legendHandle.AutoUpdate = 'off';
legendHandle.UserData.Lines = lineHandles;
legendHandle.UserData.BaseNames = lineNames;
legendHandle.UserData.Highlighted = gobjects(0);
legendHandle.ItemHitFcn = @highlightLine;

signalFigure.UserData.plot2ProfileLines = lineHandles;
if isfield(signalFigure.UserData, 'cursorTool')
    cursorData = signalFigure.UserData.cursorTool;
    cursorData.axes = signalAxes;
    cursorData.legend = legendHandle;
    cursorData.lastLegendUpdate = -Inf;
    signalFigure.UserData.cursorTool = cursorData;
end
end
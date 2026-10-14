function [lineHandles, unavailableIds] = apply_plot2_signal_profile( ...
    signalFigure, signalAxes, legendHandle, logObj, catalog, signalIds, ...
    t0, targetTrajectory)
%APPLY_PLOT2_SIGNAL_PROFILE Replace plotted signals and refresh legend handles.

fixedLegendPosition = [];
fixedAxesPosition = [];
if isgraphics(legendHandle)
    legendUserData = legendHandle.UserData;
    if isstruct(legendUserData) && isfield(legendUserData, 'FixedPosition')
        fixedLegendPosition = legendUserData.FixedPosition;
    end
    if isstruct(legendUserData) && isfield(legendUserData, 'FixedAxesPosition')
        fixedAxesPosition = legendUserData.FixedAxesPosition;
    end
end
if isempty(fixedAxesPosition) && isfield(signalAxes.UserData, 'FixedPosition')
    fixedAxesPosition = signalAxes.UserData.FixedPosition;
end

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
    lineNames{lineIndex} = lineHandles(lineIndex).DisplayName;
end

if isempty(lineHandles)
    legendHandle.String = {};
    legendHandle.Visible = 'off';
else
    legendHandle = legend(signalAxes, lineHandles, lineNames);
    legendHandle.Visible = 'on';
end
legendHandle.Units = 'normalized';
legendHandle.Location = 'none';
if ~isempty(lineHandles)
    legendHandle.String = reserveLegendValueWidth(lineHandles, lineNames);
    fixedLegendPosition = legendHandle.Position;
else
    if isempty(fixedLegendPosition)
        fixedLegendPosition = legendHandle.Position;
    end
end
legendHandle.String = lineNames;
legendHandle.Position = fixedLegendPosition;
legendHandle.AutoUpdate = 'off';
legendHandle.UserData.Lines = lineHandles;
legendHandle.UserData.BaseNames = lineNames;
legendHandle.UserData.Highlighted = gobjects(0);
legendHandle.ItemHitFcn = @highlightLine;
legendHandle.UserData.FixedPosition = fixedLegendPosition;
if ~isempty(fixedAxesPosition)
    signalAxes.Position = fixedAxesPosition;
    legendHandle.UserData.FixedAxesPosition = fixedAxesPosition;
end

signalFigure.UserData.plot2ProfileLines = lineHandles;
if isfield(signalFigure.UserData, 'cursorTool')
    cursorData = signalFigure.UserData.cursorTool;
    cursorData.axes = signalAxes;
    cursorData.legend = legendHandle;
    cursorData.lastLegendUpdate = -Inf;
    signalFigure.UserData.cursorTool = cursorData;
end
end

function reservedNames = reserveLegendValueWidth(lineHandles, lineNames)
reservedNames = lineNames;
for lineIndex = 1:numel(lineHandles)
    yData = lineHandles(lineIndex).YData;
    finiteYData = yData(isfinite(yData));
    if isempty(finiteYData)
        continue;
    end
    minimumWidth = numel(sprintf('%.3f', min(finiteYData)));
    maximumWidth = numel(sprintf('%.3f', max(finiteYData)));
    reservedNames{lineIndex} = sprintf('%s = %s', lineNames{lineIndex}, ...
        repmat('8', 1, max(minimumWidth, maximumWidth)));
end
end
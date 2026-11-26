function [lineHandles, unavailableIds, legendHandle] = apply_plot2_signal_profile( ...
    signalFigure, signalAxes, legendHandle, logObj, catalog, signalIds, ...
    t0, targetTrajectory)
%APPLY_PLOT2_SIGNAL_PROFILE Replace plotted signals and refresh legend handles.

fields = get_plot2_signal_panel_fields(signalFigure, signalAxes);
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

if isfield(signalFigure.UserData, fields.lines)
    oldLines = signalFigure.UserData.(fields.lines);
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
    lineUserData = lineHandles(lineIndex).UserData;
    lineUserData.OrigLineWidth = lineHandles(lineIndex).LineWidth;
    lineUserData.OrigColor = lineHandles(lineIndex).Color;
    lineUserData.OriginalYData = lineHandles(lineIndex).YData;
    lineUserData.ScaleMode = 'none';
    lineUserData.ScaleFactor = 1;
    lineUserData.ScaleMaxAbs = NaN;
    lineHandles(lineIndex).UserData = lineUserData;
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
legendHandle.UserData.DisplayNames = lineNames;
legendHandle.UserData.Highlighted = gobjects(0);
if isfield(legendHandle.UserData, 'ScaleTarget')
    legendHandle.UserData = rmfield(legendHandle.UserData, 'ScaleTarget');
end
legendHandle.ItemHitFcn = @highlightLine;
scaleMenu = uicontextmenu(ancestor(legendHandle, 'figure'));
scaleMenu.ContextMenuOpeningFcn = ...
    @(~, ~) set_plot2_legend_target(legendHandle);
uimenu(scaleMenu, 'Label', 'Задать коэффициент...', ...
    'Callback', @(~, ~) set_plot2_line_scale(legendHandle, 'factor'));
uimenu(scaleMenu, 'Label', 'Сбросить масштаб', ...
    'Callback', @(~, ~) set_plot2_line_scale(legendHandle, 'reset'));
uimenu(scaleMenu, 'Label', 'Авто: % по модулю', ...
    'Callback', @(~, ~) set_plot2_line_scale(legendHandle, 'auto'));
uimenu(scaleMenu, 'Label', 'Выделить на передний план', ...
    'Callback', @(~, ~) bring_plot2_line_to_front(legendHandle));
uimenu(scaleMenu, 'Label', 'Удалить', 'Separator', 'on', ...
    'Callback', @(~, ~) delete_plot2_profile_line( ...
        signalFigure, signalAxes, legendHandle, logObj, catalog, ...
        t0, targetTrajectory));
legendHandle.ContextMenu = scaleMenu;
legendHandle.UserData.FixedPosition = fixedLegendPosition;
if ~isempty(fixedAxesPosition)
    signalAxes.Position = fixedAxesPosition;
    legendHandle.UserData.FixedAxesPosition = fixedAxesPosition;
end

signalFigure.UserData.(fields.lines) = lineHandles;
signalFigure.UserData.(fields.legend) = legendHandle;
if isfield(signalFigure.UserData, 'cursorTool')
    cursorData = signalFigure.UserData.cursorTool;
    if isfield(signalFigure.UserData, 'plot2ComparisonAxes') && ...
            isequal(signalFigure.UserData.plot2ComparisonAxes, signalAxes)
        cursorData.comparisonAxes = signalAxes;
        cursorData.comparisonLegend = legendHandle;
    else
        cursorData.axes = signalAxes;
        cursorData.legend = legendHandle;
    end
    cursorData.lastLegendUpdate = -Inf;
    signalFigure.UserData.cursorTool = cursorData;
end
end

function set_plot2_legend_target(legendHandle)
legendData = legendHandle.UserData;
if isfield(legendData, 'ScaleTarget')
    legendData = rmfield(legendData, 'ScaleTarget');
end
lineHandles = legendData.Lines;
lineCount = numel(lineHandles);
if lineCount == 0
    return;
end

figureHandle = ancestor(legendHandle, 'figure');
legendPosition = getpixelposition(legendHandle, true);
pointerPosition = figureHandle.CurrentPoint;
if pointerPosition(1) < legendPosition(1) || ...
        pointerPosition(1) > legendPosition(1) + legendPosition(3) || ...
        pointerPosition(2) < legendPosition(2) || ...
        pointerPosition(2) > legendPosition(2) + legendPosition(4)
    return;
end

switch legendHandle.Orientation
    case 'vertical'
        positionInList = 1 - ...
            (pointerPosition(2) - legendPosition(2)) / legendPosition(4);
    case 'horizontal'
        positionInList = ...
            (pointerPosition(1) - legendPosition(1)) / legendPosition(3);
    otherwise
        return;
end
lineIndex = min(lineCount, max(1, floor(positionInList * lineCount) + 1));
if strcmp(legendHandle.Direction, 'reverse')
    lineIndex = lineCount - lineIndex + 1;
end

legendData.ScaleTarget = lineHandles(lineIndex);
legendHandle.UserData = legendData;
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
function bring_plot2_line_to_front(legendHandle)
%BRING_PLOT2_LINE_TO_FRONT Raise the selected profile line above other plots.

if isempty(legendHandle) || ~isgraphics(legendHandle)
    return;
end

legendData = legendHandle.UserData;
if ~isstruct(legendData) || ~isfield(legendData, 'ScaleTarget') || ...
        ~isgraphics(legendData.ScaleTarget)
    return;
end

lineHandle = legendData.ScaleTarget;
uistack(lineHandle, 'top');

figureHandle = ancestor(legendHandle, 'figure');
if isfield(figureHandle.UserData, 'cursorTool')
    cursorLine = figureHandle.UserData.cursorTool.cursorLine;
    if ~isempty(cursorLine) && isgraphics(cursorLine)
        uistack(cursorLine, 'top');
    end
end
end

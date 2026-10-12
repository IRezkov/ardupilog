function set_cursor_from_click(signalFigure)
    if isempty(signalFigure) || ~isvalid(signalFigure)
        return;
    end
    if ~isfield(signalFigure.UserData, 'cursorTool')
        return;
    end

    data = signalFigure.UserData.cursorTool;
    if ~data.enabled
        return;
    end

    clickedObject = hittest(signalFigure);
    clickedAxes = ancestor(clickedObject, 'axes');
    if isempty(clickedAxes) || ~isequal(clickedAxes, data.axes)
        return;
    end

    figurePoint = get(signalFigure, 'CurrentPoint');
    axesRectangle = getpixelposition(data.axes, true);
    insideAxes = figurePoint(1) >= axesRectangle(1) && ...
        figurePoint(1) <= axesRectangle(1) + axesRectangle(3) && ...
        figurePoint(2) >= axesRectangle(2) && ...
        figurePoint(2) <= axesRectangle(2) + axesRectangle(4);
    if ~insideAxes
        return;
    end

    point = get(data.axes, 'CurrentPoint');
    update_cursor_tool(signalFigure, point(1, 1));
end

function start_plot2_cursor_drag(lineHandle, signalFigure)
if ~isgraphics(signalFigure) || ~isgraphics(lineHandle)
    return;
end
data = signalFigure.UserData.cursorTool;
if ~data.enabled
    return;
end

data.dragging = true;
data.activeAxes = ancestor(lineHandle, 'axes');
signalFigure.UserData.cursorTool = data;
if can_change_window_callbacks(signalFigure)
    signalFigure.WindowButtonMotionFcn = @(src, ~) update_cursor_tool(src);
    signalFigure.WindowButtonUpFcn = @(src, ~) stop_cursor_drag(src);
end
end

function stop_cursor_drag(signalFigure)
if ~isgraphics(signalFigure)
    return;
end
data = signalFigure.UserData.cursorTool;
data.dragging = false;
signalFigure.UserData.cursorTool = data;
if can_change_window_callbacks(signalFigure)
    signalFigure.WindowButtonMotionFcn = [];
    signalFigure.WindowButtonUpFcn = [];
end
end

function allowed = can_change_window_callbacks(signalFigure)
try
    allowed = strcmpi(zoom(signalFigure).Enable, 'off') && ...
        strcmpi(pan(signalFigure).Enable, 'off') && ...
        strcmpi(rotate3d(signalFigure).Enable, 'off');
catch
    allowed = true;
end
end

function toggle_cursor_tool(src, ~, signalFigure)
    if isempty(signalFigure) || ~isvalid(signalFigure)
        return;
    end

    data = signalFigure.UserData.cursorTool;
    data.enabled = logical(src.Value);
    data.dragging = false;
    signalFigure.UserData.cursorTool = data;

    if data.enabled
        src.String = 'Cursor: ON';
        src.BackgroundColor = [0.75 0.9 0.75];
        if can_change_window_callbacks(signalFigure)
            signalFigure.WindowButtonMotionFcn = [];
            signalFigure.WindowButtonDownFcn = @(src, ~) set_cursor_from_click(src);
        end
        visibleRange = xlim(data.axes);
        update_cursor_tool(signalFigure, mean(visibleRange));
        data = signalFigure.UserData.cursorTool;
        if ~isempty(data.cursorLine) && isvalid(data.cursorLine)
            data.cursorLine.Visible = 'on';
            data.cursorLine.ButtonDownFcn = @(lineHandle, ~) start_cursor_drag(lineHandle, signalFigure);
        end
    else
        src.String = 'Cursor: OFF';
        src.BackgroundColor = get(0, 'defaultuicontrolbackgroundcolor');
        if can_change_window_callbacks(signalFigure)
            signalFigure.WindowButtonMotionFcn = [];
            signalFigure.WindowButtonUpFcn = [];
            signalFigure.WindowButtonDownFcn = [];
        end
        if ~isempty(data.cursorLine) && isvalid(data.cursorLine)
            data.cursorLine.Visible = 'off';
        end
    end

    signalFigure.UserData.cursorTool = data;
end

function start_cursor_drag(lineHandle, signalFigure)
    if ~isvalid(signalFigure) || ~isvalid(lineHandle)
        return;
    end
    data = signalFigure.UserData.cursorTool;
    if ~data.enabled
        return;
    end

    data.dragging = true;
    signalFigure.UserData.cursorTool = data;
    if can_change_window_callbacks(signalFigure)
        signalFigure.WindowButtonMotionFcn = @(src, ~) update_cursor_tool(src);
        signalFigure.WindowButtonUpFcn = @(src, ~) stop_cursor_drag(src);
    end
end

function stop_cursor_drag(signalFigure)
    if isempty(signalFigure) || ~isvalid(signalFigure)
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

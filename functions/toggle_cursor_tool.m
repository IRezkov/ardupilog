function toggle_cursor_tool(src, ~, signalFigure)
    if isempty(signalFigure) || ~isvalid(signalFigure)
        return;
    end

    enabled = logical(src.Value);
    apply_cursor_enabled(signalFigure, enabled);

    if enabled
        data = signalFigure.UserData.cursorTool;
        visibleRange = xlim(data.axes);
        update_cursor_tool(signalFigure, mean(visibleRange));
    end
end

function apply_cursor_enabled(signalFigure, enabled)
    data = signalFigure.UserData.cursorTool;
    data.enabled = enabled;
    data.dragging = false;
    cursorLines = data.cursorLine;
    if isfield(data, 'comparisonCursorLine')
        cursorLines = [cursorLines, data.comparisonCursorLine];
    end
    signalFigure.UserData.cursorTool = data;

    if isfield(signalFigure.UserData, 'cursorToggle') && ...
            isgraphics(signalFigure.UserData.cursorToggle)
        toggle = signalFigure.UserData.cursorToggle;
        toggle.Value = enabled;
        if enabled
            toggle.String = 'Cursor: ON';
            toggle.BackgroundColor = [0.75 0.9 0.75];
        else
            toggle.String = 'Cursor: OFF';
            toggle.BackgroundColor = get(0, 'defaultuicontrolbackgroundcolor');
        end
    end

    if enabled
        if can_change_window_callbacks(signalFigure)
            signalFigure.WindowButtonMotionFcn = [];
            signalFigure.WindowButtonDownFcn = @(src, ~) set_cursor_from_click(src);
        end
        for lineIndex = 1:numel(cursorLines)
            if isgraphics(cursorLines(lineIndex))
                cursorLines(lineIndex).Visible = 'on';
                cursorLines(lineIndex).ButtonDownFcn = ...
                    @(lineHandle, ~) start_plot2_cursor_drag(lineHandle, signalFigure);
            end
        end
    else
        if can_change_window_callbacks(signalFigure)
            signalFigure.WindowButtonMotionFcn = [];
            signalFigure.WindowButtonUpFcn = [];
            signalFigure.WindowButtonDownFcn = [];
        end
        for lineIndex = 1:numel(cursorLines)
            if isgraphics(cursorLines(lineIndex))
                cursorLines(lineIndex).Visible = 'off';
            end
        end
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

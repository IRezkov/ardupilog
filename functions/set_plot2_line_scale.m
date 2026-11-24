function set_plot2_line_scale(legendHandle, operation, factor)
%SET_PLOT2_LINE_SCALE Scale or restore the line most recently clicked in legend.

if nargin < 3
    factor = [];
end
if isempty(legendHandle) || ~isgraphics(legendHandle)
    return;
end

legendData = legendHandle.UserData;
if ~isstruct(legendData) || ~isfield(legendData, 'ScaleTarget') || ...
        ~isgraphics(legendData.ScaleTarget)
    return;
end
lineHandle = legendData.ScaleTarget;
lineData = lineHandle.UserData;
if ~isstruct(lineData) || ~isfield(lineData, 'OriginalYData')
    return;
end

switch operation
    case 'factor'
        if isempty(factor)
            answer = inputdlg('Введите коэффициент масштабирования:', ...
                'Масштаб линии', 1, {'1'});
            if isempty(answer)
                return;
            end
            factor = str2double(strrep(answer{1}, ',', '.'));
        end
        if ~isnumeric(factor) || ~isreal(factor) || ~isscalar(factor) || ...
                ~isfinite(factor)
            errordlg('Коэффициент должен быть конечным действительным числом.', ...
                'Некорректный коэффициент');
            return;
        end
        scaledY = lineData.OriginalYData .* factor;
        lineData.ScaleMode = 'factor';
        lineData.ScaleFactor = factor;
        lineData.ScaleMaxAbs = NaN;
    case 'reset'
        scaledY = lineData.OriginalYData;
        lineData.ScaleMode = 'none';
        lineData.ScaleFactor = 1;
        lineData.ScaleMaxAbs = NaN;
    case 'auto'
        originalY = lineData.OriginalYData;
        finiteValues = originalY(isfinite(originalY));
        if isempty(finiteValues)
            warning('plot2:NoFiniteLineData', ...
                'Нельзя автоматически масштабировать линию без конечных значений.');
            return;
        end
        maxAbsValue = max(abs(finiteValues));
        if maxAbsValue == 0
            scaledY = originalY;
        else
            scaledY = originalY ./ maxAbsValue .* 100;
        end
        lineData.ScaleMode = 'auto';
        lineData.ScaleFactor = 1;
        lineData.ScaleMaxAbs = maxAbsValue;
    otherwise
        error('plot2:UnknownScaleOperation', ...
            'Неизвестная операция масштабирования: %s', operation);
end

lineHandle.YData = scaledY;
cacheFields = {'CursorSortedX', 'CursorSortedY', 'CursorSortedXDataLength'};
for i = 1:numel(cacheFields)
    if isfield(lineData, cacheFields{i})
        lineData = rmfield(lineData, cacheFields{i});
    end
end
lineHandle.UserData = lineData;

lineIndex = find(legendData.Lines == lineHandle, 1);
if ~isempty(lineIndex)
    displayNames = legendData.BaseNames;
    for i = 1:numel(legendData.Lines)
        currentLine = legendData.Lines(i);
        if ~isgraphics(currentLine)
            continue;
        end
        currentLineData = currentLine.UserData;
        switch currentLineData.ScaleMode
            case 'factor'
                scaleLabel = sprintf(' ×%.6g', currentLineData.ScaleFactor);
            case 'auto'
                if currentLineData.ScaleMaxAbs == 0
                    scaleLabel = ' [% по модулю, max=0]';
                else
                    scaleLabel = ' [% по модулю]';
                end
            otherwise
                scaleLabel = '';
        end
        displayNames{i} = [displayNames{i}, scaleLabel];
    end
    legendData.DisplayNames = displayNames;
    legendHandle.UserData = legendData;
    legendHandle.String = displayNames;
    if isfield(legendData, 'FixedPosition')
        legendHandle.Position = legendData.FixedPosition;
    end
end

figureHandle = ancestor(legendHandle, 'figure');
if isfield(figureHandle.UserData, 'cursorTool')
    cursorData = figureHandle.UserData.cursorTool;
    cursorData.lastLegendUpdate = -Inf;
    figureHandle.UserData.cursorTool = cursorData;
    if cursorData.enabled && isfinite(cursorData.currentTime)
        update_cursor_tool(figureHandle, cursorData.currentTime);
    end
end
end

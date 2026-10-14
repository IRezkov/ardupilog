function highlightLine(lg, ev)
    clickedLine = ev.Peer;
    highlighted = lg.UserData.Highlighted;
    
    % Цвета для 4 линий: красный, зелёный, синий, оранжевый
    colors = [1 0 0; ...
              0.2 0.9 0.2; ...
              0 0 1; ...
              1 0.6 0.2];

    % Сохраняем исходные параметры линии.
    if isempty(clickedLine.UserData.OrigLineWidth)
        clickedLine.UserData.OrigLineWidth = clickedLine.LineWidth;
    end
    if isempty(clickedLine.UserData.OrigColor)
        clickedLine.UserData.OrigColor = clickedLine.Color;
    end
    % Если кликнули по уже подсвеченной — снимаем подсветку
    for i = numel(highlighted):-1:1
        if isequal(highlighted(i), clickedLine)
            clickedLine.LineWidth = clickedLine.UserData.OrigLineWidth;
            clickedLine.Color      = clickedLine.UserData.OrigColor;
            highlighted(i) = [];
            
            % Переназначаем цвета оставшимся
            for j = 1:numel(highlighted)
                highlighted(j).LineWidth = 4;
                highlighted(j).Color = colors(j, :);
            end
            lg.UserData.Highlighted = highlighted;
            restoreLegendAndAxesPosition(lg);
            return;
        end
    end

    % Если уже подсвечено 4 линии — убираем первую (самую старую)
    if numel(highlighted) >= 4
        highlighted(1).LineWidth = highlighted(1).UserData.OrigLineWidth;
        highlighted(1).Color      = highlighted(1).UserData.OrigColor;
        highlighted(1) = [];
    end

    % Подсвечиваем новую линию
    clickedLine.LineWidth = 4;
    highlighted = [highlighted, clickedLine];

    % Переназначаем цвета всем: 1‑я — красная, 2‑я — зелёная, 3‑я — синяя, 4‑я — оранжевая
    for j = 1:numel(highlighted)
        highlighted(j).LineWidth = 4;
        highlighted(j).Color = colors(j, :);
    end

    lg.UserData.Highlighted = highlighted;

    restoreLegendAndAxesPosition(lg);
end

function restoreLegendAndAxesPosition(lg)
    if isfield(lg.UserData, 'FixedAxesPosition')
        axesHandle = ancestor(lg, 'axes');
        if ~isempty(axesHandle) && isvalid(axesHandle)
            axesHandle.Position = lg.UserData.FixedAxesPosition;
        end
    end
    if isfield(lg.UserData, 'FixedPosition')
        lg.Position = lg.UserData.FixedPosition;
    end
end

function keep = find_time_outliers(msg, threshold, verbose)
    
    t = double(msg.TimeS(:));
    n = numel(t);
    keep = true(n, 1);

    if nargin < 2 || isempty(threshold)
        threshold = 15.0;
    end
    if nargin < 3
        verbose = true;
    end

    if ~isprop(msg, 'TimeS')
        if verbose, warning('Поле TimeS не найдено.'); end
        return;
    end

    if n < 3
        if verbose, fprintf('Слишком мало точек (%d).\n', n); end
        return;
    end

    % --- Межточечные интервалы ---
    dt = diff(t);

    finite_mask = isfinite(dt);
    if ~all(finite_mask)
        dt(~finite_mask) = median(dt(finite_mask));
    end

    med_dt = median(dt);
    mad_dt = median(abs(dt - med_dt));

    if mad_dt > 0
        z = abs(dt - med_dt) / (1.4826 * mad_dt);
    else
        sd = std(dt);
        if sd == 0
            if verbose, fprintf('Все интервалы одинаковы — выбросов нет.\n'); end
            return;
        end
        z = abs(dt - med_dt) / sd;
    end

    % --- Аномальные интервалы ---
    abnormal = find(z > threshold);

    if isempty(abnormal)
        if verbose, fprintf('Выбросов не найдено (%d точек).\n', n); end
        return;
    end

    % --- Голосование по точкам ---
    % Интервал dt(j) связывает точки j и j+1.
    % Внутренний выброс создаёт 2 аномальных интервала → 2 голоса.
    % Крайний выброс (первая/последняя точка) → 1 голос.
    votes = zeros(n, 1);
    votes(abnormal)       = votes(abnormal) + 1;       % левые концы
    votes(abnormal + 1)   = votes(abnormal + 1) + 1;   % правые концы

    outlier_idx = find(votes >= 2);

    % Крайние точки с 1 голосом — тоже выбросы
    if votes(1) == 1
        outlier_idx = [outlier_idx; 1];
    end
    if votes(n) == 1
        outlier_idx = [outlier_idx; n];
    end

    outlier_idx = sort(unique(outlier_idx));

    if isempty(outlier_idx)
        if verbose, fprintf('Выбросов не найдено (%d точек).\n', n); end
        return;
    end

    % --- Удаление из всех полей ---
    keep(outlier_idx) = false;
end

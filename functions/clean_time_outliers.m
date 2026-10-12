function msg = clean_time_outliers(msg, threshold, verbose)
% CLEAN_TIME_OUTLIERS  Удаляет точки-выбросы из сообщения ardupilog.
%   Анализирует межточечные интервалы TimeS: если интервал скачет
%   на много порядков от типичного — обе связанные точки помечаются,
%   затем голосованием определяется, какая именно точка — выброс.
%   Найденные индексы удаляются из ВСЕХ полей сообщения.
%
%   msg = clean_time_outliers(log.THR)
%   msg = clean_time_outliers(log.THR, 15.0)
%   msg = clean_time_outliers(log.THR, 15.0, true)
%
%   threshold — порог MAD z-score, по умолчанию 15.
%   verbose   — печатать отчёт, по умолчанию true.

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

    t = double(msg.TimeS(:));
    n = numel(t);

    if n < 3
        if verbose, fprintf('Слишком мало точек (%d).\n', n); end
        return;
    end

    % --- Проверка временной оси ---
    % TimeS должен быть конечным и неубывающим. Нулевая точка допустима
    % только в начале последовательности; ноль внутри лога обычно означает
    % повреждённую запись.
    dt = diff(t);
    outlier_idx = find(~isfinite(t) | t < 0);
    middleZero = find(t == 0 & (1:n).' > 1);
    outlier_idx = [outlier_idx; middleZero];

    % Любое уменьшение времени указывает на плохую текущую точку.
    nonIncreasing = find(isfinite(dt) & dt <= 0);
    outlier_idx = [outlier_idx; nonIncreasing];

    positiveDt = dt(isfinite(dt) & dt > 0);
    if isempty(positiveDt)
        typicalDt = NaN;
    else
        typicalDt = median(positiveDt);
    end

    % MSG может иметь законные большие паузы между сообщениями. Поэтому
    % положительные скачки чистим только у сообщений без Message-поля.
    isVariableIntervalMessage = isprop(msg, 'Message');
    if ~isVariableIntervalMessage && isfinite(typicalDt) && typicalDt > 0
        robustScale = 1.4826 * median(abs(positiveDt - typicalDt));
        limit = max(threshold * typicalDt, typicalDt + threshold * robustScale);
        forwardJumps = find(dt > limit);
        backwardJumps = find(dt < 0);

        % Изолированный выброс создаёт большой скачок вперёд и возврат.
        % Удаляем только точки между ними, а не соседние корректные записи.
        for i = 1:numel(forwardJumps)
            startIdx = forwardJumps(i);
            returnIdx = backwardJumps(find(backwardJumps > startIdx, 1, 'first'));
            if ~isempty(returnIdx)
                outlier_idx = [outlier_idx; (startIdx + 1:returnIdx).']; %#ok<AGROW>
            end
        end
    end

    outlier_idx = sort(unique(outlier_idx));

    if isempty(outlier_idx)
        if verbose, fprintf('Выбросов не найдено (%d точек).\n', n); end
        return;
    end

    % --- Удаление из всех полей ---
    keep = true(n, 1);
    keep(outlier_idx) = false;

    field_names = fieldnames(msg);
    for i = 1:numel(field_names)
        fn = field_names{i};

        % Для зависимых свойств объекта (например, TimeS) запись запрещена:
        % значение должно вычисляться из базовых полей, а не задаваться вручную.
        if isobject(msg)
            propInfo = findprop(msg, fn);
            if ~isempty(propInfo) && propInfo.Dependent
                continue;
            end
        end

        val = msg.(fn);
        % if isnumeric(val) && isvector(val) && length(val) == n
        %     result = val(keep);
        %     if isrow(val)
        %         result = result.';
        %     end
        %     msg.(fn) = result;
        % end
        if height(val) == n
            result = val(keep,:);
            if isrow(val)
                result = result.';
            end
            msg.(fn) = result;
        end

        if verbose
            if ~isempty(outlier_idx)
                if strcmp(fn, 'Message')
                    disp('выброшены сообщения');
                    disp(val(outlier_idx,:));
                end
            end
        end
    end

    if verbose
        fprintf('Удалено %d точек-выбросов из %d. Осталось %d.\n', ...
            numel(outlier_idx), n, n - numel(outlier_idx));
        fprintf('Индексы: %s\n', mat2str(outlier_idx(:)'));
        fprintf('  TimeS: значения %s, типичный интервал = %.6g\n', ...
            mat2str(t(outlier_idx)'), typicalDt);
    end
end

function msg = clean_time_outliers(msg, threshold, verbose)
% CLEAN_TIME_OUTLIERS  Удаляет точки-выбросы из сообщения ardupilog.
%   Удаляет строки с некорректными или не возрастающими временными метками.
%   Положительные большие интервалы сохраняются: они могут быть законными
%   паузами или пропусками данных.
%
%   msg = clean_time_outliers(log.THR)
%   msg = clean_time_outliers(log.THR, 15.0)
%   msg = clean_time_outliers(log.THR, 15.0, true)
%
%   threshold — оставлен для совместимости; больше не используется.
%   verbose   — печатать отчёт, по умолчанию true.

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
        fprintf('  TimeS: значения %s\n', mat2str(t(outlier_idx)'));
    end
end

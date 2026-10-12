function clean_msg(log, fieldName, threshold, verbose)
% CLEAN_MSG  Очищает поле лога от выбросов и записывает результат обратно в log.
%   clean_msg(log, 'MSG')
%   clean_msg(log, 'MSG', 10000)
%   clean_msg(log, 'MSG', 10000, true)
%
%   Функция изменяет log на месте и ничего не возвращает.

    if nargin < 2 || isempty(fieldName)
        error('clean_msg:MissingFieldName', 'Не указано имя поля.');
    end
    if nargin < 3 || isempty(threshold)
        threshold = 10000;
    end
    if nargin < 4 || isempty(verbose)
        verbose = false;
    end
    disp(fieldName);

    obj = get_field_value(log, fieldName);
    if isempty(obj)
        return;
    end

    cleaned = clean_time_outliers(obj, threshold, verbose);
    if isempty(cleaned)
        return;
    end

    try
        if isstruct(log)
            log.(fieldName) = cleaned;
            return;
        end

        if isobject(log)
            if isprop(log, fieldName)
                log.(fieldName) = cleaned;
                return;
            end

            try
                set(log, fieldName, cleaned);
                return;
            catch
            end
        end
    catch ME
        warning('clean_msg:WriteFailed', ...
            'Не удалось переписать поле %s внутри log: %s', fieldName, ME.message);
    end
end

function paramHistory = extract_param_history(log)
    paramHistory = containers.Map('KeyType', 'char', 'ValueType', 'any');
    P = get_field_value(log, 'PARM');
    if isempty(P)
        return;
    end

    names = [];
    values = [];

    if istable(P)
        if ~ismember('Name', P.Properties.VariableNames) || ~ismember('Value', P.Properties.VariableNames)
            return;
        end
        names = P.Name(:);
        values = P.Value(:);
    elseif isstruct(P)
        if isfield(P, 'Name') && isfield(P, 'Value')
            names = P.Name(:);
            values = P.Value(:);
        end
    elseif isobject(P)
        if has_field_value(P, 'Name') && has_field_value(P, 'Value')
            names = get_field_value(P, 'Name');
            values = get_field_value(P, 'Value');
        end
    end

    if isempty(names) || isempty(values)
        return;
    end

    namesCell = flatten_param_names(names);
    valuesCell = flatten_param_values(values);
    n = min(numel(namesCell), numel(valuesCell));
    for k = 1:n
        key = normalize_param_name(namesCell{k});
        if isempty(key)
            continue;
        end
        if ~isKey(paramHistory, key)
            paramHistory(key) = {};
        end
        arr = paramHistory(key);
        if ~iscell(arr)
            arr = {arr};
        end
        arr{end + 1} = valuesCell{k};
        paramHistory(key) = arr;
    end
end

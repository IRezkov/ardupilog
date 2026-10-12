function key = normalize_param_name(nameVal)
    if isempty(nameVal)
        key = '';
        return;
    end
    if iscell(nameVal)
        key = normalize_param_name(nameVal{1});
        return;
    end
    if isstring(nameVal)
        key = char(nameVal);
        return;
    end
    key = char(string(nameVal));
    key = strtrim(key);
end
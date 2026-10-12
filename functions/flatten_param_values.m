function valuesCell = flatten_param_values(values)
    if iscell(values)
        valuesCell = values(:);
        return;
    end
    if isstring(values)
        valuesCell = cellstr(values(:));
        return;
    end
    if ischar(values)
        valuesCell = cellstr(values);
        return;
    end
    valuesCell = num2cell(values(:));
end
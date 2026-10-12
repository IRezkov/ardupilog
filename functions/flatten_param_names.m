function namesCell = flatten_param_names(names)
    if iscell(names)
        namesCell = names(:);
        return;
    end
    if isstring(names)
        namesCell = cellstr(names(:));
        return;
    end
    if ischar(names)
        namesCell = cellstr(names);
        return;
    end
    namesCell = num2cell(names(:));
end
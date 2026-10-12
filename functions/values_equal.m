function tf = values_equal(a, b)
    if isempty(a) && isempty(b)
        tf = true;
        return;
    end
    if isempty(a) || isempty(b)
        tf = false;
        return;
    end
    if isnumeric(a) && isnumeric(b)
        tf = isequaln(a, b);
        return;
    end
    if ischar(a) && ischar(b)
        tf = strcmp(a, b);
        return;
    end
    if iscell(a) && iscell(b)
        tf = isequal(a, b);
        return;
    end
    tf = isequaln(a, b);
end

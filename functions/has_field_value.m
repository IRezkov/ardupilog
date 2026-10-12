function tf = has_field_value(obj, fieldName)
    if isstruct(obj)
        tf = isfield(obj, fieldName);
    elseif isobject(obj)
        tf = isprop(obj, fieldName);
    else
        tf = false;
    end
end
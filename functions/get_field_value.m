function val = get_field_value(obj, fieldName)
    if isempty(obj)
        val = [];
        return;
    end

    if isstruct(obj)
        if isfield(obj, fieldName)
            val = obj.(fieldName);
        else
            val = [];
        end
        return;
    end

    if isobject(obj)
        if isprop(obj, fieldName)
            val = obj.(fieldName);
        else
            val = [];
        end
        return;
    end

    val = [];
end
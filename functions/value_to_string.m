function s = value_to_string(val)
    if ischar(val)
        s = val;
        return;
    end

    if iscell(val)
        s = strjoin(cellfun(@(x) value_to_string(x), val, 'UniformOutput', false), ', ');
        return;
    end

    if isnumeric(val) || islogical(val)
        if numel(val) == 1
            s = num2str(val);
        else
            s = sprintf('%s', mat2str(val));
        end
        return;
    end

    s = char(string(val));
end

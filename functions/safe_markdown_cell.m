function s = safe_markdown_cell(value)
    if isempty(value)
        s = '-';
        return;
    end

    if iscell(value)
        s = strjoin(cellfun(@(x) safe_markdown_cell(x), value, 'UniformOutput', false), '; ');
        return;
    end

    if isnumeric(value) || islogical(value)
        s = format_numeric_markdown(value);
        return;
    end

    s = char(string(value));
    s = strrep(s, '\n', ' ');
    s = strrep(s, '|', '\\|');
end

function s = format_numeric_markdown(value)
    if isempty(value)
        s = '-';
        return;
    end

    if isnumeric(value) || islogical(value)
        if numel(value) ~= 1 || isnan(value)
            s = 'N/A';
            return;
        end
        s = num2str(value);
        return;
    end

    s = safe_markdown_cell(value);
end

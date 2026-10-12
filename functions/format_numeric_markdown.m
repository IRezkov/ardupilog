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

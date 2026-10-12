function dt = parse_datetime_from_filename(fileName)
    dt = [];
    s = fileName;
    s = strrep(s, '_', ' ');
    s = strrep(s, '-', ' ');
    s = regexprep(s, '([AP]M)', '');
    s = strtrim(s);

    tokens = regexp(s, '(\d{4})\s+(\d{1,2})\s+(\d{1,2})\s+(\d{1,2})\s+(\d{2})\s+(\d{2})', 'tokens');
    if ~isempty(tokens)
        tok = tokens{1};
        if numel(tok) >= 6
            year = str2double(tok{1});
            month = str2double(tok{2});
            day = str2double(tok{3});
            hour = str2double(tok{4});
            minute = str2double(tok{5});
            second = str2double(tok{6});
            dt = datetime(year, month, day, hour, minute, second);
        end
    end
end
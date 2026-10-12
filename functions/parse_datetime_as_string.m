function s = parse_datetime_as_string(fileName)
    dt = parse_datetime_from_filename(fileName);
    if isempty(dt)
        s = '';
    else
        s = char(dt, 'yyyy-MM-dd HH:mm:ss');
    end
end
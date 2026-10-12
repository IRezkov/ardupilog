function epoch = log_start_epoch(filePath)
    epoch = inf;
    candidate = basename_from_path(filePath);
    fallback = parse_datetime_from_filename(candidate);
    if ~isempty(fallback)
        epoch = datenum(fallback);
        return;
    end

    % Do not open the binary here. The log is parsed once in the summary loop.
end
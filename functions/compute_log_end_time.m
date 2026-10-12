function endTime = compute_log_end_time(log)
    allTimes = [];

    candidates = {'MODE', 'GPS', 'STER', 'THR'};
    for c = 1:numel(candidates)
        obj = get_field_value(log, candidates{c});
        if ~isempty(obj)
            obj = clean_time_outliers(obj, 100, false);
            vals = get_field_value(obj, 'TimeS');
            if ~isempty(vals)
                vals = double(vals(:));
                allTimes = [allTimes; vals(time_outlier_mask(vals, 100))];
            end
        end
    end

    if isempty(allTimes)
        endTime = [];
        return;
    end

    allTimes = allTimes(~isnan(allTimes) & isfinite(allTimes));
    if isempty(allTimes)
        endTime = [];
        return;
    end

    endTime = max(allTimes);
end
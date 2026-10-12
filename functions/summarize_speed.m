function [avgSpeed, maxSpeed] = summarize_speed(log)
    avgSpeed = NaN;
    maxSpeed = NaN;

    candidates = {};
    gpsObj = get_field_value(log, 'GPS');
    if ~isempty(gpsObj)
        gpsObj = clean_time_outliers(gpsObj, 100, false);
        gpsSpd = get_field_value(gpsObj, 'Spd');
        gpsTime = get_field_value(gpsObj, 'TimeS');
        if ~isempty(gpsSpd) && ~isempty(gpsTime) && numel(gpsSpd) == numel(gpsTime)
            vals = double(gpsSpd);
            candidates{end + 1} = vals(time_outlier_mask(gpsTime, 100));
        end
    end
    thrObj = get_field_value(log, 'THR');
    if ~isempty(thrObj)
        thrObj = clean_time_outliers(thrObj, 100, false);
        thrSpeed = get_field_value(thrObj, 'Speed');
        thrTime = get_field_value(thrObj, 'TimeS');
        if ~isempty(thrSpeed) && ~isempty(thrTime) && numel(thrSpeed) == numel(thrTime)
            vals = double(thrSpeed);
            candidates{end + 1} = vals(time_outlier_mask(thrTime, 100));
        end
    end

    for i = 1:numel(candidates)
        vals = candidates{i};
        vals = vals(~isnan(vals) & isfinite(vals));
        if isempty(vals)
            continue;
        end
        avgSpeed = mean(vals);
        maxSpeed = max(vals);
        return;
    end
end
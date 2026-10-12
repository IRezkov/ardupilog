function durationSec = compute_duration(log)
    timeVec = [];

    modeObj = get_field_value(log, 'MODE');
    if ~isempty(modeObj)
        modeObj = clean_time_outliers(modeObj, 100, false);
        vals = get_field_value(modeObj, 'TimeS');
        if ~isempty(vals)
            vals = double(vals(:));
            timeVec = [timeVec; vals(time_outlier_mask(vals, 100))];
        end
    end

    obj = get_field_value(log, 'GPS');
    if ~isempty(obj)
        obj = clean_time_outliers(obj, 100, false);
        vals = get_field_value(obj, 'TimeS');
        if ~isempty(vals)
            vals = double(vals(:));
            timeVec = [timeVec; vals(time_outlier_mask(vals, 100))];
        end
    end

    % clean_msg(log, 'STER', 10, 1);
    % obj = get_field_value(log, 'STER');
    % if ~isempty(obj)
    %     obj = clean_time_outliers(obj);
    %     vals = get_field_value(obj, 'TimeS');
    %     if ~isempty(vals)
    %         timeVec = [timeVec; double(vals(:))];
    %     end
    % end

    obj = get_field_value(log, 'THR');
    if ~isempty(obj)
        obj = clean_time_outliers(obj, 100, false);
        vals = get_field_value(obj, 'TimeS');
        if ~isempty(vals)
            vals = double(vals(:));
            timeVec = [timeVec; vals(time_outlier_mask(vals, 100))];
        end
    end

    if isempty(timeVec)
        durationSec = 0;
        return;
    end

    timeVec = double(timeVec(~isnan(timeVec) & isfinite(timeVec)));
    if isempty(timeVec)
        durationSec = 0;
        return;
    end

    

    durationSec = max(timeVec) - min(timeVec);
    if ~isfinite(durationSec) || durationSec < 0
        durationSec = 0;
    end
    if durationSec == 0 && ~isempty(timeVec)
        durationSec = max(timeVec) - min(timeVec);
    end
end
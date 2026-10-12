function maxThrottle = summarize_max_throttle_out_from_rec(rec, log)
    maxThrottle = NaN;
    if isempty(rec) || ~isfield(rec, 'FileName')
        return;
    end

    if nargin < 2 || isempty(log)
        if isfield(rec, 'MaxThrottleOut')
            maxThrottle = rec.MaxThrottleOut;
        end
        return;
    end

    thrObj = get_field_value(log, 'THR');
    if isempty(thrObj)
        return;
    end

    throttleOut = get_field_value(thrObj, 'ThrOut');
    if isempty(throttleOut)
        throttleOut = get_field_value(thrObj, 'ThrottleOut');
    end
    if isempty(throttleOut)
        return;
    end

    vals = double(throttleOut(:));
    vals = vals(~isnan(vals) & isfinite(vals));
    if isempty(vals)
        return;
    end

    maxThrottle = max(abs(vals));
end

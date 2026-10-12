function keep = is_meaningful_log(rec, minDurationSec, minSpeedMps, minThrottleOut)
    global MIN_DURATION_SEC MIN_SPEED_MPS MIN_THROTTLE_OUT
    keep = false;

    if isempty(rec)
        return;
    end

    if nargin < 2 || isempty(minDurationSec)
        minDurationSec = MIN_DURATION_SEC;
    end
    if nargin < 3 || isempty(minSpeedMps)
        minSpeedMps = MIN_SPEED_MPS;
    end
    if nargin < 4 || isempty(minThrottleOut)
        minThrottleOut = MIN_THROTTLE_OUT;
    end

    durationSec = rec.DurationSec;
    maxSpeed = rec.MaxSpeedMps;
    maxThrottleOut = summarize_max_throttle_out_from_rec(rec);

    if ~isnumeric(durationSec) || isnan(durationSec)
        durationSec = 0;
    end
    if ~isnumeric(maxSpeed) || isnan(maxSpeed)
        maxSpeed = 0;
    end
    if ~isnumeric(maxThrottleOut) || isnan(maxThrottleOut)
        maxThrottleOut = 0;
    end

    if durationSec < minDurationSec
        keep = (maxSpeed >= (minSpeedMps + 0.2)) || (maxThrottleOut >= (minThrottleOut + 0.05));
    else
        keep = (maxSpeed >= minSpeedMps);
    end
end

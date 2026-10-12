function keep = time_outlier_mask(timeValues, threshold)
    if nargin < 2 || isempty(threshold)
        threshold = 100;
    end

    timeValues = double(timeValues(:));
    n = numel(timeValues);
    keep = true(n, 1);
    if n < 3
        return;
    end

    dt = diff(timeValues);
    finiteMask = isfinite(dt);
    if ~any(finiteMask)
        keep(:) = false;
        return;
    end
    dt(~finiteMask) = median(dt(finiteMask));

    typicalDt = median(dt);
    if ~isfinite(typicalDt) || typicalDt <= 0
        return;
    end

    limit = threshold * typicalDt;
    forwardJumps = find(dt > limit);
    backwardJumps = find(dt < -limit);
    outlierIdx = [];

    for i = 1:numel(forwardJumps)
        startIdx = forwardJumps(i);
        returnIdx = backwardJumps(find(backwardJumps > startIdx, 1, 'first'));
        if isempty(returnIdx)
            returnIdx = n;
        end
        outlierIdx = [outlierIdx; (startIdx + 1:returnIdx)'];
    end

    for i = 1:numel(backwardJumps)
        startIdx = backwardJumps(i);
        if any(forwardJumps < startIdx)
            continue;
        end
        returnIdx = forwardJumps(find(forwardJumps > startIdx, 1, 'first'));
        if isempty(returnIdx)
            returnIdx = n;
        end
        outlierIdx = [outlierIdx; (startIdx + 1:returnIdx)'];
    end

    outlierIdx = unique(outlierIdx);
    keep(outlierIdx) = false;
end

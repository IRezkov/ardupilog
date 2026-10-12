function trajectory = build_target_trajectory(log, t0)
    trajectory = struct('time', [], 'actualNorth', [], 'targetNorth', [], ...
        'actualEast', [], 'targetEast', [], 'errorM', [], 'originLat', NaN, ...
        'originLon', NaN, 'metersPerDegree', 111319.9);

    if ~isprop(log, 'PSCN') || ~isprop(log, 'PSCE') || ...
            isempty(log.PSCN) || isempty(log.PSCE)
        return;
    end
    if ~isprop(log, 'ORGN') || isempty(log.ORGN)
        return;
    end

    if ~all([isprop(log.PSCN, 'TimeS'), isprop(log.PSCN, 'PN'), ...
            isprop(log.PSCN, 'TPN'), isprop(log.PSCE, 'TimeS'), ...
            isprop(log.PSCE, 'PE'), isprop(log.PSCE, 'TPE')])
        return;
    end

    northTime = double(log.PSCN.TimeS(:));
    northActual = double(log.PSCN.PN(:));
    northTarget = double(log.PSCN.TPN(:));
    eastTime = double(log.PSCE.TimeS(:));
    eastActual = double(log.PSCE.PE(:));
    eastTarget = double(log.PSCE.TPE(:));

    validNorth = isfinite(northTime) & isfinite(northActual) & isfinite(northTarget);
    validEast = isfinite(eastTime) & isfinite(eastActual) & isfinite(eastTarget);
    northTime = northTime(validNorth);
    northActual = northActual(validNorth);
    northTarget = northTarget(validNorth);
    eastTime = eastTime(validEast);
    eastActual = eastActual(validEast);
    eastTarget = eastTarget(validEast);
    if numel(northTime) < 2 || numel(eastTime) < 2
        return;
    end

    [northTime, northOrder] = sort(northTime);
    [eastTime, eastOrder] = sort(eastTime);
    northActual = northActual(northOrder);
    northTarget = northTarget(northOrder);
    eastActual = eastActual(eastOrder);
    eastTarget = eastTarget(eastOrder);
    [northTime, northUnique] = unique(northTime, 'stable');
    [eastTime, eastUnique] = unique(eastTime, 'stable');
    northActual = northActual(northUnique);
    northTarget = northTarget(northUnique);
    eastActual = eastActual(eastUnique);
    eastTarget = eastTarget(eastUnique);

    time = northTime(northTime >= eastTime(1) & northTime <= eastTime(end));
    if numel(time) < 2
        return;
    end
    trajectory.time = time - t0;
    trajectory.actualNorth = interp1(northTime, northActual, time, 'linear');
    trajectory.targetNorth = interp1(northTime, northTarget, time, 'linear');
    trajectory.actualEast = interp1(eastTime, eastActual, time, 'linear');
    trajectory.targetEast = interp1(eastTime, eastTarget, time, 'linear');
    trajectory.errorM = hypot(trajectory.actualNorth - trajectory.targetNorth, ...
        trajectory.actualEast - trajectory.targetEast);
    trajectory.originLat = double(log.ORGN.Lat(1));
    trajectory.originLon = double(log.ORGN.Lng(1));
end

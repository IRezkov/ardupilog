function summaryTable = build_segmented_summary_table(processedLogs, paramMaps, precomputedSegments)
    summaryTable = table();
    if isempty(processedLogs) || isempty(paramMaps)
        return;
    end
    if nargin < 3
        precomputedSegments = {};
    end

    rows = {};
    for i = 1:numel(processedLogs)
        rec = processedLogs{i};
        if isempty(rec)
            continue;
        end

        % Reuse segments computed once during log parsing when available, so
        % the (potentially huge) parsed Log object does not need to stay in
        % memory for every log at once just to rebuild segments here.
        segs = {};
        if i <= numel(precomputedSegments)
            segs = precomputedSegments{i};
        else
            currentMap = [];
            if i <= numel(paramMaps)
                currentMap = paramMaps{i};
            end

            logObj = [];
            if ~isempty(currentMap) && isfield(currentMap, 'Log')
                logObj = currentMap.Log;
            end

            if ~isempty(logObj)
                segs = build_log_parameter_mode_segments(logObj, rec);
            end
        end

        if isempty(segs)
            rows{end + 1} = rec;
        else
            for s = 1:numel(segs)
                rows{end + 1} = segs{s};
            end
        end
    end

    if isempty(rows)
        return;
    end

    allFields = {};
    for r = 1:numel(rows)
        f = fieldnames(rows{r});
        for k = 1:numel(f)
            if ~ismember(f{k}, allFields)
                allFields{end + 1} = f{k};
            end
        end
    end

    for r = 1:numel(rows)
        rowFields = fieldnames(rows{r});
        missingFields = setdiff(allFields, rowFields);
        for k = 1:numel(missingFields)
            rows{r}.(missingFields{k}) = [];
        end
    end

    firstRow = rows{1};
    summaryTable = struct2table(firstRow, 'AsArray', true);
    for r = 2:numel(rows)
        nextRow = rows{r};
        summaryTable = [summaryTable; struct2table(nextRow, 'AsArray', true)];
    end
end

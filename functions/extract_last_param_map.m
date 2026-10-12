function paramMap = extract_last_param_map(log, cutoffTime)
    if nargin < 2 || isempty(cutoffTime)
        cutoffTime = Inf;
    end
    paramMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    P = get_field_value(log, 'PARM');
    if isempty(P)
        return;
    end

    if istable(P)
        if ~ismember('Name', P.Properties.VariableNames) || ~ismember('Value', P.Properties.VariableNames)
            return;
        end
        names = P.Name(:);
        values = P.Value(:);
        timeValues = get_param_time_values(P, numel(names));
        for k = 1:numel(names)
            if timeValues(k) > cutoffTime
                continue;
            end
            key = normalize_param_name(names{k});
            if ~isempty(key)
                paramMap(key) = values(k);
            end
        end
        return;
    end

    if isstruct(P)
        if isfield(P, 'Name') && isfield(P, 'Value')
            names = P.Name(:);
            values = P.Value(:);
            timeValues = get_param_time_values(P, numel(names));
            for k = 1:numel(names)
                if timeValues(k) > cutoffTime
                    continue;
                end
                key = normalize_param_name(names{k});
                if ~isempty(key)
                    paramMap(key) = values(k);
                end
            end
            return;
        end

        fn = fieldnames(P);
        for k = 1:numel(fn)
            key = fn{k};
            val = P.(key);
            if ~isempty(val)
                paramMap(char(key)) = val;
            end
        end
        return;
    end

    if isobject(P)
        if has_field_value(P, 'Name') && has_field_value(P, 'Value')
            names = get_field_value(P, 'Name');
            values = get_field_value(P, 'Value');
            if ~isempty(names) && ~isempty(values)
                namesCell = flatten_param_names(names);
                valuesCell = flatten_param_values(values);
                n = min(numel(namesCell), numel(valuesCell));
                timeValues = get_param_time_values(P, n);
                for k = 1:n
                    if timeValues(k) > cutoffTime
                        continue;
                    end
                    key = normalize_param_name(namesCell{k});
                    if ~isempty(key)
                        paramMap(key) = valuesCell{k};
                    end
                end
                return;
            end
        end
    end

    if iscell(P)
        for k = 1:numel(P)
            if isempty(P{k})
                continue;
            end
                subMap = extract_last_param_map(struct('PARM', P{k}), cutoffTime);
            if ~isempty(subMap)
                keysList = keys(subMap);
                for j = 1:numel(keysList)
                    key = keysList{j};
                    paramMap(key) = subMap(key);
                end
            end
        end
    end
end

function timeValues = get_param_time_values(paramData, count)
    timeValues = zeros(count, 1);
    if istable(paramData) && ismember('TimeS', paramData.Properties.VariableNames)
        rawTimes = paramData.TimeS(:);
    elseif isstruct(paramData) && isfield(paramData, 'TimeS')
        rawTimes = paramData.TimeS(:);
    elseif isobject(paramData) && has_field_value(paramData, 'TimeS')
        rawTimes = get_field_value(paramData, 'TimeS');
        rawTimes = rawTimes(:);
    else
        return;
    end
    rawTimes = double(rawTimes);
    countToCopy = min(count, numel(rawTimes));
    timeValues(1:countToCopy) = rawTimes(1:countToCopy);
    timeValues(~isfinite(timeValues)) = Inf;
end
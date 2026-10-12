function paramTable = build_changed_param_table(paramMaps, includeInLogChanges)
    paramTable = table();
    if isempty(paramMaps)
        return;
    end

    if nargin < 2 || isempty(includeInLogChanges)
        includeInLogChanges = true;
    end

    rows = {};
    prevMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');

    for i = 1:numel(paramMaps)
        currentMap = paramMaps{i}.Map;
        currentHistory = [];
        if isfield(paramMaps{i}, 'History')
            currentHistory = paramMaps{i}.History;
        end

        if includeInLogChanges && ~isempty(currentHistory)
            historyKeys = keys(currentHistory);
            for j = 1:numel(historyKeys)
                paramName = char(historyKeys{j});
                if ~is_control_relevant_param(paramName)
                    continue;
                end

                vals = currentHistory(paramName);
                if ~iscell(vals)
                    vals = {vals};
                end

                for k = 2:numel(vals)
                    prevVal = vals{k - 1};
                    currentVal = vals{k};
                    if values_equal(prevVal, currentVal)
                        continue;
                    end

                    entryKey = sprintf('%s|%s|%s|%s', paramMaps{i}.FileName, paramName, value_to_string(prevVal), value_to_string(currentVal));
                    if isKey(seen, entryKey)
                        continue;
                    end

                    valueSummary = sprintf('%s: %s -> %s', paramMaps{i}.FileName, value_to_string(prevVal), value_to_string(currentVal));
                    rows{end + 1} = struct('ParamName', paramName, 'ValueSummary', valueSummary);
                    seen(entryKey) = true;
                end
            end
        end

        if isempty(currentMap)
            prevMap = currentMap;
            continue;
        end

        relevantNames = keys(currentMap);
        for j = 1:numel(relevantNames)
            paramName = char(relevantNames{j});
            if ~is_control_relevant_param(paramName)
                continue;
            end

            currentVal = currentMap(paramName);
            prevVal = [];
            if ~isempty(prevMap) && isKey(prevMap, paramName)
                prevVal = prevMap(paramName);
            end

            if isempty(prevVal) || ~values_equal(prevVal, currentVal)
                if ~isempty(prevVal)
                    entryKey = sprintf('%s|%s|%s|%s', paramMaps{i}.FileName, paramName, value_to_string(prevVal), value_to_string(currentVal));
                    if isKey(seen, entryKey)
                        continue;
                    end
                    valueSummary = sprintf('%s: %s -> %s', paramMaps{i}.FileName, value_to_string(prevVal), value_to_string(currentVal));
                    rows{end + 1} = struct('ParamName', paramName, 'ValueSummary', valueSummary);
                    seen(entryKey) = true;
                end
            end
        end

        prevMap = currentMap;
    end

    if isempty(rows)
        return;
    end

    groupedRows = {};
    groupedIndex = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for i = 1:numel(rows)
        row = rows{i};
        if isKey(groupedIndex, row.ParamName)
            rowIndex = groupedIndex(row.ParamName);
            groupedRows{rowIndex}.ValueSummary = [groupedRows{rowIndex}.ValueSummary, '<br>', row.ValueSummary];
        else
            groupedRows{end + 1} = row;
            groupedIndex(row.ParamName) = numel(groupedRows);
        end
    end

    paramTable = struct2table([groupedRows{:}]);
end

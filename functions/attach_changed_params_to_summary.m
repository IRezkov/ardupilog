function summaryTable = attach_changed_params_to_summary(summaryTable, paramMaps)
    if isempty(summaryTable) || isempty(paramMaps)
        return;
    end

    if ~ismember('ChangedParams', summaryTable.Properties.VariableNames)
        summaryTable.ChangedParams = repmat({''}, height(summaryTable), 1);
    else
        summaryTable.ChangedParams = cellstr(string(summaryTable.ChangedParams));
    end

    for i = 1:height(summaryTable)
        fileName = char(string(summaryTable.FileName(i)));
        paramIndex = find(cellfun(@(item) strcmp(char(string(item.FileName)), fileName), paramMaps), 1);
        if isempty(paramIndex)
            continue;
        end

        paramInfo = paramMaps{paramIndex};
        currentHistory = [];
        if isfield(paramInfo, 'History')
            currentHistory = paramInfo.History;
        end

        names = {};
        seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');

        if ~isempty(currentHistory)
            historyKeys = keys(currentHistory);
            for j = 1:numel(historyKeys)
                name = char(historyKeys{j});
                if ~is_control_relevant_param(name)
                    continue;
                end

                vals = currentHistory(name);
                if ~iscell(vals)
                    vals = {vals};
                end
                for k = 2:numel(vals)
                    prevValue = vals{k - 1};
                    currentValue = vals{k};
                    if values_equal(prevValue, currentValue)
                        continue;
                    end

                    textValue = sprintf('%s: %s -> %s', name, value_to_string(prevValue), value_to_string(currentValue));
                    if ~isKey(seen, textValue)
                        names{end + 1} = textValue;
                        seen(textValue) = true;
                    end
                end
            end
        end

        if paramIndex > 1
            previousMap = paramMaps{paramIndex - 1}.Map;
            currentMap = paramInfo.Map;
            if ~isempty(previousMap) && ~isempty(currentMap)
                currentNames = keys(currentMap);
                for j = 1:numel(currentNames)
                    name = char(currentNames{j});
                    if ~is_control_relevant_param(name) || ~isKey(previousMap, name)
                        continue;
                    end

                    previousValue = previousMap(name);
                    currentValue = currentMap(name);
                    if values_equal(previousValue, currentValue)
                        continue;
                    end

                    textValue = sprintf('%s: %s -> %s', name, value_to_string(previousValue), value_to_string(currentValue));
                    if ~isKey(seen, textValue)
                        names{end + 1} = textValue;
                        seen(textValue) = true;
                    end
                end
            end
        end

        if ~isempty(names)
            existingText = summaryTable.ChangedParams{i};
            for j = 1:numel(names)
                if isempty(strtrim(existingText))
                    existingText = names{j};
                elseif ~contains(existingText, names{j})
                    existingText = [existingText, '; ', names{j}];
                end
            end
            summaryTable.ChangedParams{i} = existingText;
        end
    end
end

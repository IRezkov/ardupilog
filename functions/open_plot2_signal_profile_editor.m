function open_plot2_signal_profile_editor( ...
    signalFigure, signalAxes, legendHandle, logObj, catalog, t0, targetTrajectory)
%OPEN_PLOT2_SIGNAL_PROFILE_EDITOR Open the checkbox-tree profile editor.

persistent activeEditor
if ~isempty(activeEditor) && isvalid(activeEditor)
    delete(activeEditor);
end

profiles = load_plot2_signal_profiles();
profileNames = {profiles.name};
activeProfileName = 'Main';
if ispref('MissionPlannerPlot2', 'ActiveSignalProfile')
    activeProfileName = getpref('MissionPlannerPlot2', 'ActiveSignalProfile');
end
selectedProfileIndex = find(strcmp(profileNames, activeProfileName), 1);
if isempty(selectedProfileIndex)
    selectedProfileIndex = find(strcmp(profileNames, 'Main'), 1);
    if isempty(selectedProfileIndex)
        selectedProfileIndex = 1;
    end
end

currentProfileName = '';
hasCurrentPlotSignals = false;
currentPlotSignals = {};
if ~isempty(signalFigure) && isvalid(signalFigure) && ...
        isstruct(signalFigure.UserData)
    if isfield(signalFigure.UserData, 'plot2ProfileName')
        currentProfileName = signalFigure.UserData.plot2ProfileName;
        if isstring(currentProfileName) && isscalar(currentProfileName)
            currentProfileName = char(currentProfileName);
        end
    end
    if isfield(signalFigure.UserData, 'plot2ProfileSignals')
        currentPlotSignals = signalFigure.UserData.plot2ProfileSignals;
        hasCurrentPlotSignals = true;
    end
end
if ~isempty(currentProfileName)
    currentProfileIndex = find(strcmp(profileNames, currentProfileName), 1);
    if ~isempty(currentProfileIndex)
        selectedProfileIndex = currentProfileIndex;
    end
end
selectedProfileName = profiles(selectedProfileIndex).name;
selectedSignalIds = normalize_signal_ids(profiles(selectedProfileIndex).signalIds);
if hasCurrentPlotSignals
    selectedSignalIds = normalize_signal_ids(currentPlotSignals);
end
visibleSignalIds = {};
isBuildingTree = false;

activeEditor = uifigure('Name', 'Plot2 signal profiles', ...
    'Position', [100 100 570 700], 'Tag', 'Plot2SignalProfileEditor');
profileDrop = uidropdown(activeEditor, ...
    'Items', profileNames, ...
    'Value', profileNames{selectedProfileIndex}, ...
    'Tag', 'Plot2ProfileSelector', ...
    'Position', [12 660 380 26], ...
    'ValueChangedFcn', @selectProfile);
uibutton(activeEditor, 'Text', 'New', 'Tag', 'Plot2NewSignalProfile', ...
    'Position', [402 660 72 26], 'ButtonPushedFcn', @newProfile);
deleteButton = uibutton(activeEditor, 'Text', 'Delete', ...
    'Tag', 'Plot2DeleteSignalProfile', ...
    'Position', [484 660 74 26], 'ButtonPushedFcn', @deleteProfile);

nameField = uieditfield(activeEditor, 'text', ...
    'Value', selectedProfileName, ...
    'Tag', 'Plot2ProfileName', ...
    'Position', [12 622 462 26]);
if ~strcmp(selectedProfileName, profileDrop.Value)
    deleteButton.Enable = 'off';
end
uibutton(activeEditor, 'Text', 'Save', 'Tag', 'Plot2SaveSignalProfile', ...
    'Position', [484 622 74 26], 'ButtonPushedFcn', @saveProfile);
searchField = uieditfield(activeEditor, 'text', ...
    'Placeholder', 'Search signals', ...
    'Tag', 'Plot2ProfileSearch', ...
    'Position', [12 582 546 26], ...
    'ValueChangedFcn', @filterSignals);
tree = uitree(activeEditor, 'checkbox', ...
    'Tag', 'Plot2SignalTree', ...
    'Position', [12 92 546 480], ...
    'CheckedNodesChangedFcn', @checkedNodesChanged);
statusLabel = uilabel(activeEditor, ...
    'Position', [12 56 546 24], 'Text', '');
uibutton(activeEditor, 'Text', 'Apply to plot', ...
    'Tag', 'Plot2ApplySignalProfile', ...
    'Position', [402 12 156 34], 'ButtonPushedFcn', @applyProfile);

rebuild_tree(selectedSignalIds);

    function selectProfile(~, event)
        deleteButton.Enable = 'on';
        profileIndex = find(strcmp({profiles.name}, event.Value), 1);
        if isempty(profileIndex)
            return;
        end
        selectedSignalIds = normalize_signal_ids(profiles(profileIndex).signalIds);
        nameField.Value = profiles(profileIndex).name;
        rebuild_tree(selectedSignalIds);
        statusLabel.Text = sprintf('%d signals selected', numel(selectedSignalIds));
    end

    function newProfile(~, ~)
        sync_selection_from_tree();
        deleteButton.Enable = 'off';
        selectedSignalIds = {};
        nameField.Value = 'New profile';
        rebuild_tree(selectedSignalIds);
        statusLabel.Text = 'Unsaved profile';
    end

    function saveProfile(~, ~)
        sync_selection_from_tree();
        profileName = strtrim(nameField.Value);
        if isempty(profileName)
            uialert(activeEditor, 'Enter a profile name.', 'Profile name');
            return;
        end

        profileIndex = find(strcmp({profiles.name}, profileName), 1);
        profile = struct('name', profileName, 'signalIds', {selectedSignalIds});
        if isempty(profileIndex)
            profiles(end + 1) = profile;
        else
            profiles(profileIndex) = profile;
        end
        save_plot2_signal_profiles(profiles);
        deleteButton.Enable = 'on';
        refresh_profile_list(profileName);
        statusLabel.Text = sprintf('Saved %d signals', numel(selectedSignalIds));
    end

    function deleteProfile(~, ~)
        if numel(profiles) <= 1
            uialert(activeEditor, 'At least one profile must remain.', 'Delete profile');
            return;
        end

        profileIndex = find(strcmp({profiles.name}, profileDrop.Value), 1);
        if isempty(profileIndex)
            statusLabel.Text = 'Select a saved profile before deleting';
            return;
        end
        profiles(profileIndex) = [];
        save_plot2_signal_profiles(profiles);
        profileIndex = min(profileIndex, numel(profiles));
        profileDrop.Items = {profiles.name};
        profileDrop.Value = profiles(profileIndex).name;
        deleteButton.Enable = 'on';
        selectedSignalIds = normalize_signal_ids(profiles(profileIndex).signalIds);
        nameField.Value = profiles(profileIndex).name;
        rebuild_tree(selectedSignalIds);
        statusLabel.Text = 'Profile deleted';
    end

    function filterSignals(~, ~)
        sync_selection_from_tree();
        rebuild_tree(selectedSignalIds);
    end

    function checkedNodesChanged(~, ~)
        sync_selection_from_tree();
        statusLabel.Text = sprintf('%d signals selected', numel(selectedSignalIds));
    end

    function applyProfile(~, ~)
        sync_selection_from_tree();
        if isempty(signalFigure) || ~isvalid(signalFigure) || ...
                isempty(signalAxes) || ~isvalid(signalAxes) || ...
                isempty(legendHandle) || ~isvalid(legendHandle)
            uialert(activeEditor, 'The plot window is no longer available.', 'Apply profile');
            return;
        end
        profileName = strtrim(nameField.Value);
        if isempty(profileName)
            uialert(activeEditor, 'Enter a profile name.', 'Profile name');
            return;
        end

        [~, unavailableIds] = apply_plot2_signal_profile( ...
            signalFigure, signalAxes, legendHandle, logObj, catalog, ...
            selectedSignalIds, t0, targetTrajectory);

        profileIndex = find(strcmp({profiles.name}, profileName), 1);
        profile = struct('name', profileName, 'signalIds', {selectedSignalIds});
        if isempty(profileIndex)
            profiles(end + 1) = profile;
        else
            profiles(profileIndex) = profile;
        end
        save_plot2_signal_profiles(profiles);
        deleteButton.Enable = 'on';
        refresh_profile_list(profileName);
        setpref('MissionPlannerPlot2', 'ActiveSignalProfile', profileName);

        signalFigure.UserData.plot2ProfileName = profileName;
        signalFigure.UserData.plot2ProfileSignals = selectedSignalIds;
        signalFigure.UserData.plot2UnavailableSignals = unavailableIds;
        if isempty(unavailableIds)
            statusLabel.Text = sprintf('Applied %d signals', numel(selectedSignalIds));
        else
            statusLabel.Text = sprintf('Applied; %d signals are unavailable in this log', ...
                numel(unavailableIds));
        end
    end

    function rebuild_tree(checkedIds)
        isBuildingTree = true;
        delete(tree.Children);
        searchText = lower(strtrim(searchField.Value));
        if isempty(searchText)
            matches = true(1, numel(catalog));
        else
            matches = false(1, numel(catalog));
            for entryIndex = 1:numel(catalog)
                matches(entryIndex) = contains(lower(catalog(entryIndex).id), searchText) || ...
                    contains(lower(catalog(entryIndex).label), searchText);
            end
        end

        visibleCatalog = catalog(matches);
        visibleSignalIds = {visibleCatalog.id};
        leafNodes = {};

        priorityIds = preferred_signal_ids();
        catalogIds = {visibleCatalog.id};
        presentPriorityIds = priorityIds(ismember(priorityIds, catalogIds));
        priorityIndices = cellfun(@(signalId) find( ...
            strcmp(catalogIds, signalId), 1), presentPriorityIds);
        priorityEntries = visibleCatalog(priorityIndices);
        priorityMask = ismember(catalogIds, priorityIds);
        remainingEntries = visibleCatalog(~priorityMask);

        if ~isempty(priorityEntries)
            priorityGroup = uitreenode(tree, ...
                'Text', 'Frequently used', 'NodeData', 'group:priority');
            for entryIndex = 1:numel(priorityEntries)
                entry = priorityEntries(entryIndex);
                leafNode = uitreenode(priorityGroup, ...
                    'Text', entry.label, 'NodeData', entry.id);
                if ismember(entry.id, checkedIds)
                    leafNodes{end + 1} = leafNode; %#ok<AGROW>
                end
            end
        end

        groupNames = sort(unique({remainingEntries.group}));
        for groupIndex = 1:numel(groupNames)
            groupName = groupNames{groupIndex};
            groupEntries = remainingEntries( ...
                strcmp({remainingEntries.group}, groupName));
            fieldSortKey = lower(string({groupEntries.field}) + "|" + ...
                string({groupEntries.label}));
            [~, fieldOrder] = sort(fieldSortKey);
            groupEntries = groupEntries(fieldOrder);
            groupNode = uitreenode(tree, 'Text', groupName, ...
                'NodeData', ['group:' groupName]);
            for entryIndex = 1:numel(groupEntries)
                entry = groupEntries(entryIndex);
                leafNode = uitreenode(groupNode, ...
                    'Text', entry.label, 'NodeData', entry.id);
                if ismember(entry.id, checkedIds)
                    leafNodes{end + 1} = leafNode; %#ok<AGROW>
                end
            end
        end

        missingIds = checkedIds(~ismember(checkedIds, {catalog.id}));
        [~, missingOrder] = sort(lower(string(missingIds)));
        missingIds = missingIds(missingOrder);
        missingMatches = false(size(missingIds));
        for missingIndex = 1:numel(missingIds)
            missingMatches(missingIndex) = isempty(searchText) || ...
                contains(lower(missingIds{missingIndex}), searchText);
        end
        missingIds = missingIds(missingMatches);
        if ~isempty(missingIds)
            missingGroup = uitreenode(tree, ...
                'Text', 'Not in this log', 'NodeData', 'group:missing');
            for missingIndex = 1:numel(missingIds)
                missingNode = uitreenode(missingGroup, ...
                    'Text', [missingIds{missingIndex} ' (unavailable)'], ...
                    'NodeData', missingIds{missingIndex});
                leafNodes{end + 1} = missingNode; %#ok<AGROW>
                visibleSignalIds{end + 1} = missingIds{missingIndex}; %#ok<AGROW>
            end
        end

        if ~isempty(leafNodes)
            tree.CheckedNodes = [leafNodes{:}];
        end
        isBuildingTree = false;
        drawnow limitrate;
    end

    function sync_selection_from_tree()
        if isBuildingTree
            return;
        end
        hiddenIds = selectedSignalIds(~ismember(selectedSignalIds, visibleSignalIds));
        checkedIds = get_checked_signal_ids(tree);
        selectedSignalIds = unique([hiddenIds, checkedIds], 'stable');
    end

    function refresh_profile_list(selectedName)
        profileDrop.Items = {profiles.name};
        profileDrop.Value = selectedName;
    end
end

function signalIds = preferred_signal_ids()
signalIds = {
    'STER.DesTurnRate', 'STER.TurnRate', 'Derived.SpeedKmh', ...
    'Derived.DesSpeedKmh', 'THR.Speed', 'THR.DesSpeed', ...
    'Derived.ThrOutFiltered', 'THR.ThrOut', 'Derived.SteerOutScaled', ...
    'STER.SteerOut', 'ANKL.Target', 'ANKR.Target', 'SUTS.RPos', ...
    'Derived.RPMLScaled', 'Derived.RPMRScaled', ...
    'Derived.ErrorNorth', 'Derived.ErrorEast', 'Derived.TargetError', ...
    'GPS.Spd', 'GPS.Lat', 'GPS.Lng', 'MODE.Mode', ...
    'XKF1.PN', 'XKF1.PE', 'XKF1.VN', 'XKF1.VE', ...
    'PSCN.PN', 'PSCN.TPN', 'PSCE.PE', 'PSCE.TPE', ...
    'STER.LatAcc', 'STER.DesLatAcc', 'ANKL.Gas', 'ANKL.RPM', ...
    'ANKR.Gas', 'ANKR.RPM'};
end

function signalIds = get_checked_signal_ids(tree)
signalIds = {};
checkedNodes = tree.CheckedNodes;
for nodeIndex = 1:numel(checkedNodes)
    nodeData = checkedNodes(nodeIndex).NodeData;
    if ischar(nodeData) && ~startsWith(nodeData, 'group:')
        signalIds{end + 1} = nodeData; %#ok<AGROW>
    end
end
signalIds = unique(signalIds, 'stable');
end

function signalIds = normalize_signal_ids(signalIds)
if isstring(signalIds)
    signalIds = cellstr(signalIds(:));
elseif ischar(signalIds)
    signalIds = {signalIds};
end
if isempty(signalIds)
    signalIds = {};
else
    signalIds = unique(signalIds, 'stable');
end
end
function profiles = load_plot2_signal_profiles()
%LOAD_PLOT2_SIGNAL_PROFILES Load saved profiles or create the initial profile.

preferenceGroup = 'MissionPlannerPlot2';
preferenceName = 'SignalProfiles';
if ispref(preferenceGroup, preferenceName)
    try
        profiles = getpref(preferenceGroup, preferenceName);
    catch
        profiles = default_profiles();
    end
else
    profiles = default_profiles();
end

if ~isstruct(profiles) || ~all(isfield(profiles, {'name', 'signalIds'}))
    profiles = default_profiles();
    return;
end
if isempty(profiles)
    profiles = default_profiles();
    return;
end
if ~isfield(profiles, 'lineScaleSettings')
    [profiles.lineScaleSettings] = deal(empty_line_scale_settings());
end
if ~isfield(profiles, 'highlightedSignalIds')
    [profiles.highlightedSignalIds] = deal({});
end

validProfiles = false(size(profiles));
for profileIndex = 1:numel(profiles)
    profileName = profiles(profileIndex).name;
    signalIds = profiles(profileIndex).signalIds;
    if isstring(profileName) && isscalar(profileName)
        profileName = char(profileName);
    end
    if isstring(signalIds)
        signalIds = cellstr(signalIds(:));
    end
    if ~ischar(profileName) || isempty(strtrim(profileName)) || ~iscell(signalIds)
        continue;
    end
    if ~all(cellfun(@(signalId) ischar(signalId) || ...
            (isstring(signalId) && isscalar(signalId)), signalIds))
        continue;
    end

    profiles(profileIndex).name = strtrim(profileName);
    profiles(profileIndex).signalIds = cellfun(@char, signalIds, ...
        'UniformOutput', false);
    profiles(profileIndex).signalIds = unique( ...
        profiles(profileIndex).signalIds, 'stable');

    scaleSettings = profiles(profileIndex).lineScaleSettings;
    if ~isstruct(scaleSettings) || ...
            ~all(isfield(scaleSettings, {'signalId', 'scaleMode', 'scaleFactor'}))
        scaleSettings = empty_line_scale_settings();
    else
        validScaleSettings = false(size(scaleSettings));
        for settingIndex = 1:numel(scaleSettings)
            signalId = scaleSettings(settingIndex).signalId;
            scaleMode = scaleSettings(settingIndex).scaleMode;
            scaleFactor = scaleSettings(settingIndex).scaleFactor;
            if isstring(signalId) && isscalar(signalId)
                signalId = char(signalId);
            end
            if isstring(scaleMode) && isscalar(scaleMode)
                scaleMode = char(scaleMode);
            end
            if ischar(signalId) && ~isempty(strtrim(signalId)) && ...
                    ischar(scaleMode) && ...
                any(strcmp(scaleMode, {'factor', 'auto'})) && ...
                    isnumeric(scaleFactor) && isreal(scaleFactor) && ...
                    isscalar(scaleFactor) && isfinite(scaleFactor)
                scaleSettings(settingIndex).signalId = strtrim(signalId);
                scaleSettings(settingIndex).scaleMode = scaleMode;
                validScaleSettings(settingIndex) = true;
            end
        end
        scaleSettings = scaleSettings(validScaleSettings);
        scaleSettings = scaleSettings( ...
            ismember({scaleSettings.signalId}, profiles(profileIndex).signalIds));
        if ~isempty(scaleSettings)
            [~, uniqueIndices] = unique( ...
                {scaleSettings.signalId}, 'stable');
            scaleSettings = scaleSettings(uniqueIndices);
        end
    end
    profiles(profileIndex).lineScaleSettings = scaleSettings;

    highlightedIds = profiles(profileIndex).highlightedSignalIds;
    if isstring(highlightedIds)
        highlightedIds = cellstr(highlightedIds(:));
    elseif ischar(highlightedIds)
        highlightedIds = {highlightedIds};
    end
    if ~iscell(highlightedIds) || ...
            ~all(cellfun(@(signalId) ischar(signalId) || ...
            (isstring(signalId) && isscalar(signalId)), highlightedIds))
        highlightedIds = {};
    else
        highlightedIds = cellfun(@char, highlightedIds, ...
            'UniformOutput', false);
        highlightedIds = unique(highlightedIds, 'stable');
        highlightedIds = highlightedIds( ...
            ismember(highlightedIds, profiles(profileIndex).signalIds));
    end
    profiles(profileIndex).highlightedSignalIds = highlightedIds;
    validProfiles(profileIndex) = true;
end

profiles = profiles(validProfiles);
if isempty(profiles)
    profiles = default_profiles();
end
end

function profiles = default_profiles()
signalIds = {
    'STER.DesTurnRate', 'STER.TurnRate', ...
    'Derived.SpeedKmh', 'Derived.DesSpeedKmh', 'Derived.ThrOutFiltered', ...
    'Derived.SteerOutScaled', 'ANKL.Target', 'ANKR.Target', 'SUTS.RPos', ...
    'Derived.RPMLScaled', 'Derived.RPMRScaled', ...
    'Derived.ErrorNorth', 'Derived.ErrorEast', 'Derived.TargetError'};
profiles = struct('name', 'Main', 'signalIds', {signalIds});
profiles.lineScaleSettings = empty_line_scale_settings();
profiles.highlightedSignalIds = {};
end

function settings = empty_line_scale_settings()
settings = struct('signalId', {}, 'scaleMode', {}, 'scaleFactor', {});
end
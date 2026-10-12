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
end
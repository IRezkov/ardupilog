function delete_plot2_profile_line( ...
    signalFigure, signalAxes, legendHandle, logObj, catalog, t0, targetTrajectory)
%DELETE_PLOT2_PROFILE_LINE Remove the selected line from the active profile.

if isempty(signalFigure) || ~isgraphics(signalFigure) || ...
        isempty(legendHandle) || ~isgraphics(legendHandle)
    return;
end
legendData = legendHandle.UserData;
if ~isstruct(legendData) || ~isfield(legendData, 'ScaleTarget') || ...
        ~isgraphics(legendData.ScaleTarget)
    return;
end
lineData = legendData.ScaleTarget.UserData;
if ~isstruct(lineData) || ~isfield(lineData, 'SignalId')
    return;
end
signalId = lineData.SignalId;

save_plot2_signal_profile_state(signalFigure);
profiles = load_plot2_signal_profiles();
profileName = signalFigure.UserData.plot2ProfileName;
profileIndex = find(strcmp({profiles.name}, profileName), 1);
if isempty(profileIndex)
    error('plot2:SignalProfileMissing', ...
        'The active signal profile "%s" no longer exists.', profileName);
end

profile = profiles(profileIndex);
profile.signalIds(strcmp(profile.signalIds, signalId)) = [];
profile.lineScaleSettings(strcmp( ...
    {profile.lineScaleSettings.signalId}, signalId)) = [];
profile.highlightedSignalIds(strcmp( ...
    profile.highlightedSignalIds, signalId)) = [];

[~, unavailableIds, legendHandle] = apply_plot2_signal_profile( ...
    signalFigure, signalAxes, legendHandle, logObj, catalog, ...
    profile.signalIds, t0, targetTrajectory);
restore_plot2_signal_profile_state(legendHandle, profile);
signalFigure.UserData.plot2ProfileName = profile.name;
signalFigure.UserData.plot2ProfileSignals = profile.signalIds;
signalFigure.UserData.plot2UnavailableSignals = unavailableIds;
signalFigure.UserData.plot2Legend = legendHandle;
profiles(profileIndex) = profile;
save_plot2_signal_profiles(profiles);
end

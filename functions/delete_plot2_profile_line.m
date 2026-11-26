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

fields = get_plot2_signal_panel_fields(signalFigure, signalAxes);
save_plot2_signal_profile_state(signalFigure, true, signalAxes);
profiles = load_plot2_signal_profiles();
profileName = signalFigure.UserData.(fields.name);
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
signalFigure.UserData.(fields.name) = profile.name;
signalFigure.UserData.(fields.signals) = profile.signalIds;
signalFigure.UserData.(fields.unavailable) = unavailableIds;
signalFigure.UserData.(fields.legend) = legendHandle;
profiles(profileIndex) = profile;
save_plot2_signal_profiles(profiles);
end

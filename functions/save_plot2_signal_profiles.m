function save_plot2_signal_profiles(profiles)
%SAVE_PLOT2_SIGNAL_PROFILES Store named signal profiles in MATLAB preferences.

if ~isstruct(profiles) || ~all(isfield(profiles, {'name', 'signalIds'}))
    error('save_plot2_signal_profiles:InvalidProfiles', ...
        'Profiles must contain name and signalIds fields.');
end

setpref('MissionPlannerPlot2', 'SignalProfiles', profiles);
end
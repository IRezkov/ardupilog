function save_mini_report_for_current_mode( ...
    signalFigure, mapFigure, logObj, outputDir, modeControl, modeLabels, modeTimes, t0)
if isempty(modeTimes)
    modeLabel = 'No mode data';
    modeStartTime = t0;
else
    modeIndex = min(max(round(modeControl.Value), 1), numel(modeTimes));
    modeLabel = char(modeLabels(modeIndex));
    modeStartTime = modeTimes(modeIndex) + t0;
end
save_mini_report_callback(signalFigure, mapFigure, logObj, ...
    outputDir, modeLabel, modeStartTime);
end

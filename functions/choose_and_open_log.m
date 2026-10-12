function choose_and_open_log(signalFigure, mapFigure, scriptPath)
selectedLogPath = select_plot2_log_file();
if isempty(selectedLogPath)
    return;
end
assignin('base', 'plot2SelectedLog', selectedLogPath);
assignin('base', 'plot2SignalFigure', signalFigure);
assignin('base', 'plot2MapFigure', mapFigure);
escapedScriptPath = strrep(scriptPath, '''', '''''');
evalin('base', sprintf('run(''%s'')', escapedScriptPath));
end

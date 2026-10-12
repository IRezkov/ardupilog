function selectedLogPath = select_plot2_log_file()
preferenceGroup = 'MissionPlannerPlot2';
folderPreference = 'LastLogFolder';
initialFolder = pwd;
if ispref(preferenceGroup, folderPreference)
    rememberedFolder = getpref(preferenceGroup, folderPreference);
    if (ischar(rememberedFolder) || ...
            (isstring(rememberedFolder) && isscalar(rememberedFolder))) && ...
            isfolder(rememberedFolder)
        initialFolder = char(rememberedFolder);
    end
end
[fileName, filePath] = uigetfile( ...
    {'*.bin', 'ArduPilot log (*.bin)'; '*.*', 'All files (*.*)'}, ...
    'Select ArduPilot log', fullfile(initialFolder, '*.bin'));
if isequal(fileName, 0)
    selectedLogPath = '';
    return;
end
selectedLogPath = fullfile(filePath, fileName);
end

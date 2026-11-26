function restore_plot2_signal_profile_state(legendHandle, profile)
%RESTORE_PLOT2_SIGNAL_PROFILE_STATE Reapply profile scale and highlight settings.

if isempty(legendHandle) || ~isgraphics(legendHandle) || ...
        ~isstruct(profile) || ...
        ~all(isfield(profile, {'lineScaleSettings', 'highlightedSignalIds'}))
    return;
end

legendData = legendHandle.UserData;
if ~isstruct(legendData) || ~isfield(legendData, 'Lines')
    return;
end

lineHandles = legendData.Lines;
for lineIndex = 1:numel(lineHandles)
    lineHandle = lineHandles(lineIndex);
    if ~isgraphics(lineHandle)
        continue;
    end
    lineData = lineHandle.UserData;
    if ~isstruct(lineData) || ~isfield(lineData, 'SignalId')
        continue;
    end
    settingIndex = find(strcmp( ...
        {profile.lineScaleSettings.signalId}, lineData.SignalId), 1);
    if isempty(settingIndex)
        continue;
    end

    legendData = legendHandle.UserData;
    legendData.ScaleTarget = lineHandle;
    legendHandle.UserData = legendData;
    setting = profile.lineScaleSettings(settingIndex);
    switch setting.scaleMode
        case 'factor'
            set_plot2_line_scale(legendHandle, 'factor', setting.scaleFactor);
        case 'auto'
            set_plot2_line_scale(legendHandle, 'auto');
    end
end

legendData = legendHandle.UserData;
highlightedIds = profile.highlightedSignalIds;
if numel(highlightedIds) > 4
    highlightedIds = highlightedIds(end - 3:end);
end
highlightedLines = gobjects(0);
highlightColors = [1 0 0; 0.2 0.9 0.2; 0 0 1; 1 0.6 0.2];
for highlightIndex = 1:numel(highlightedIds)
    lineIndex = find(arrayfun(@(lineHandle) ...
        isgraphics(lineHandle) && isstruct(lineHandle.UserData) && ...
        isfield(lineHandle.UserData, 'SignalId') && ...
        strcmp(lineHandle.UserData.SignalId, highlightedIds{highlightIndex}), ...
        lineHandles), 1);
    if isempty(lineIndex)
        continue;
    end
    lineHandle = lineHandles(lineIndex);
    lineData = lineHandle.UserData;
    lineHandle.LineWidth = 4;
    lineHandle.Color = highlightColors(size(highlightedLines, 2) + 1, :);
    highlightedLines(end + 1) = lineHandle; %#ok<AGROW>
    lineHandle.UserData = lineData;
end
legendData.Highlighted = highlightedLines;
if isfield(legendData, 'ScaleTarget')
    legendData = rmfield(legendData, 'ScaleTarget');
end
legendHandle.UserData = legendData;

figureHandle = ancestor(legendHandle, 'figure');
if isgraphics(figureHandle) && isstruct(figureHandle.UserData)
    figureData = figureHandle.UserData;
    axesHandle = ancestor(legendHandle, 'axes');
    fields = get_plot2_signal_panel_fields(figureHandle, axesHandle);
    figureData.(fields.legend) = legendHandle;
    figureHandle.UserData = figureData;
end
end

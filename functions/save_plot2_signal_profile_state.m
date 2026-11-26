function profile = save_plot2_signal_profile_state( ...
    signalFigure, persistState, signalAxes)
%SAVE_PLOT2_SIGNAL_PROFILE_STATE Capture profile scales and highlights.

if nargin < 2
    persistState = true;
end
if nargin < 3
    signalAxes = [];
end
profile = [];
if isempty(signalFigure) || ~isgraphics(signalFigure) || ...
        ~isstruct(signalFigure.UserData)
    return;
end
fields = get_plot2_signal_panel_fields(signalFigure, signalAxes);
if ~isfield(signalFigure.UserData, fields.name)
    return;
end

profileName = signalFigure.UserData.(fields.name);
if isstring(profileName) && isscalar(profileName)
    profileName = char(profileName);
end
if ~ischar(profileName) || isempty(profileName)
    return;
end

profiles = load_plot2_signal_profiles();
profileIndex = find(strcmp({profiles.name}, profileName), 1);
if isempty(profileIndex)
    signalIds = {};
    if isfield(signalFigure.UserData, fields.signals)
        signalIds = signalFigure.UserData.(fields.signals);
        if isstring(signalIds)
            signalIds = cellstr(signalIds(:));
        elseif ischar(signalIds)
            signalIds = {signalIds};
        end
        if ~iscell(signalIds)
            signalIds = {};
        end
    end
    profile = struct('name', profileName, ...
        'signalIds', {unique(signalIds, 'stable')}, ...
        'lineScaleSettings', { ...
        struct('signalId', {}, 'scaleMode', {}, 'scaleFactor', {})}, ...
        'highlightedSignalIds', {{}});
else
    profile = profiles(profileIndex);
end
if isfield(signalFigure.UserData, fields.signals)
    signalIds = signalFigure.UserData.(fields.signals);
    if isstring(signalIds)
        signalIds = cellstr(signalIds(:));
    elseif ischar(signalIds)
        signalIds = {signalIds};
    end
    if iscell(signalIds)
        profile.signalIds = unique(signalIds, 'stable');
    end
end
lineScaleSettings = profile.lineScaleSettings;
lineScaleSettings = lineScaleSettings( ...
    ismember({lineScaleSettings.signalId}, profile.signalIds));
visibleSignalIds = {};

lineHandles = gobjects(0);
if isfield(signalFigure.UserData, fields.lines)
    lineHandles = signalFigure.UserData.(fields.lines);
    lineHandles = lineHandles(isgraphics(lineHandles));
end
for lineIndex = 1:numel(lineHandles)
    lineHandle = lineHandles(lineIndex);
    lineData = lineHandle.UserData;
    if ~isstruct(lineData) || ~isfield(lineData, 'SignalId')
        continue;
    end
    signalId = lineData.SignalId;
    if isstring(signalId) && isscalar(signalId)
        signalId = char(signalId);
    end
    if ~ischar(signalId) || ~any(strcmp(signalId, profile.signalIds))
        continue;
    end
    visibleSignalIds{end + 1} = signalId; %#ok<AGROW>

    settingIndex = find(strcmp({lineScaleSettings.signalId}, signalId), 1);
    if ~isfield(lineData, 'ScaleMode') || ...
            ~isfield(lineData, 'ScaleFactor')
        continue;
    end
    if any(strcmp(lineData.ScaleMode, {'factor', 'auto'})) && ...
            isnumeric(lineData.ScaleFactor) && ...
            isscalar(lineData.ScaleFactor) && isfinite(lineData.ScaleFactor)
        setting = struct('signalId', signalId, ...
            'scaleMode', lineData.ScaleMode, ...
            'scaleFactor', lineData.ScaleFactor);
        if isempty(settingIndex)
            lineScaleSettings(end + 1) = setting; %#ok<AGROW>
        else
            lineScaleSettings(settingIndex) = setting;
        end
    elseif ~isempty(settingIndex)
        lineScaleSettings(settingIndex) = [];
    end
end
profile.lineScaleSettings = lineScaleSettings;

previousHighlights = profile.highlightedSignalIds;
previousHighlights = previousHighlights( ...
    ismember(previousHighlights, profile.signalIds));
hiddenHighlights = previousHighlights( ...
    ~ismember(previousHighlights, visibleSignalIds));
currentHighlights = {};
if isfield(signalFigure.UserData, fields.legend) && ...
        isgraphics(signalFigure.UserData.(fields.legend))
    legendData = signalFigure.UserData.(fields.legend).UserData;
    if isstruct(legendData) && isfield(legendData, 'Highlighted')
        highlightedLines = legendData.Highlighted;
        highlightedLines = highlightedLines(isgraphics(highlightedLines));
        for lineIndex = 1:numel(highlightedLines)
            lineData = highlightedLines(lineIndex).UserData;
            if ~isstruct(lineData) || ~isfield(lineData, 'SignalId')
                continue;
            end
            signalId = lineData.SignalId;
            if isstring(signalId) && isscalar(signalId)
                signalId = char(signalId);
            end
            if ischar(signalId) && any(strcmp(signalId, profile.signalIds))
                currentHighlights{end + 1} = signalId; %#ok<AGROW>
            end
        end
    end
end
profile.highlightedSignalIds = unique( ...
    [hiddenHighlights, currentHighlights], 'stable');
if numel(profile.highlightedSignalIds) > 4
    profile.highlightedSignalIds = profile.highlightedSignalIds(end - 3:end);
end

if ~isempty(profileIndex) && persistState
    profiles(profileIndex) = profile;
    save_plot2_signal_profiles(profiles);
end
end

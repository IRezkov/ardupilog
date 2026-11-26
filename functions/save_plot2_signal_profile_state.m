function profile = save_plot2_signal_profile_state(signalFigure, persistState)
%SAVE_PLOT2_SIGNAL_PROFILE_STATE Capture profile scales and highlights.

if nargin < 2
    persistState = true;
end
profile = [];
if isempty(signalFigure) || ~isgraphics(signalFigure) || ...
        ~isstruct(signalFigure.UserData) || ...
        ~isfield(signalFigure.UserData, 'plot2ProfileName')
    return;
end

profileName = signalFigure.UserData.plot2ProfileName;
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
    if isfield(signalFigure.UserData, 'plot2ProfileSignals')
        signalIds = signalFigure.UserData.plot2ProfileSignals;
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
if isfield(signalFigure.UserData, 'plot2ProfileSignals')
    signalIds = signalFigure.UserData.plot2ProfileSignals;
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
if isfield(signalFigure.UserData, 'plot2ProfileLines')
    lineHandles = signalFigure.UserData.plot2ProfileLines;
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
if isfield(signalFigure.UserData, 'plot2Legend') && ...
        isgraphics(signalFigure.UserData.plot2Legend)
    legendData = signalFigure.UserData.plot2Legend.UserData;
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

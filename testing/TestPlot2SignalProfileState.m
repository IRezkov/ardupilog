classdef TestPlot2SignalProfileState < matlab.unittest.TestCase
    methods (TestMethodSetup)
        function prepareSignalProfiles(testCase)
            preferenceGroup = 'MissionPlannerPlot2';
            preferenceNames = {'SignalProfiles', 'ActiveSignalProfile'};
            hadPreferences = false(size(preferenceNames));
            previousValues = cell(size(preferenceNames));
            for preferenceIndex = 1:numel(preferenceNames)
                preferenceName = preferenceNames{preferenceIndex};
                hadPreferences(preferenceIndex) = ...
                    ispref(preferenceGroup, preferenceName);
                if hadPreferences(preferenceIndex)
                    previousValues{preferenceIndex} = ...
                        getpref(preferenceGroup, preferenceName);
                end
            end
            testCase.addTeardown(@restore_preferences, preferenceGroup, ...
                preferenceNames, hadPreferences, previousValues);
            save_plot2_signal_profiles(make_profile({'MSG.A', 'MSG.B'}));
        end
    end

    methods (Test)
        function savesAndRestoresScaleAndHighlight(testCase)
            figureHandle = figure('Visible', 'off');
            testCase.addTeardown(@delete_figure_if_valid, figureHandle);
            axesHandle = axes('Parent', figureHandle);
            hold(axesHandle, 'on');
            originalY = [1 2 3];
            lineA = plot(axesHandle, 1:3, originalY, 'DisplayName', 'A');
            lineB = plot(axesHandle, 1:3, [4 5 6], 'DisplayName', 'B');

            lineA.UserData = struct( ...
                'SignalId', 'MSG.A', ...
                'OrigLineWidth', lineA.LineWidth, ...
                'OrigColor', lineA.Color, ...
                'OriginalYData', originalY, ...
                'ScaleMode', 'factor', ...
                'ScaleFactor', 2, ...
                'ScaleMaxAbs', NaN);
            lineB.UserData = struct( ...
                'SignalId', 'MSG.B', ...
                'OrigLineWidth', lineB.LineWidth, ...
                'OrigColor', lineB.Color, ...
                'OriginalYData', lineB.YData, ...
                'ScaleMode', 'auto', ...
                'ScaleFactor', 1, ...
                'ScaleMaxAbs', 6);
            legendHandle = legend(axesHandle, [lineA lineB], {'A', 'B'});
            legendHandle.UserData = struct( ...
                'Lines', [lineA lineB], ...
                'BaseNames', {{'A', 'B'}}, ...
                'DisplayNames', {{'A', 'B'}}, ...
                'Highlighted', lineA);
            figureHandle.UserData = struct( ...
                'plot2ProfileName', 'Main', ...
                'plot2ProfileLines', [lineA lineB], ...
                'plot2Legend', legendHandle);
            lineA.YData = originalY .* 2;
            lineA.LineWidth = 4;

            capturedProfile = save_plot2_signal_profile_state(figureHandle, false);
            testCase.verifyEqual( ...
                capturedProfile.lineScaleSettings(1).scaleFactor, 2);
            testCase.verifyEqual(capturedProfile.highlightedSignalIds, {'MSG.A'});
            storedProfile = load_plot2_signal_profiles();
            testCase.verifyEmpty(storedProfile.lineScaleSettings);
            testCase.verifyEmpty(storedProfile.highlightedSignalIds);

            save_plot2_signal_profile_state(figureHandle);
            profile = load_plot2_signal_profiles();
            testCase.verifyEqual(profile.lineScaleSettings(1).scaleMode, 'factor');
            testCase.verifyEqual(profile.lineScaleSettings(1).scaleFactor, 2);
            testCase.verifyEqual(profile.lineScaleSettings(2).scaleMode, 'auto');
            testCase.verifyEqual(profile.highlightedSignalIds, {'MSG.A'});

            lineA.YData = originalY;
            lineA.LineWidth = lineA.UserData.OrigLineWidth;
            lineA.Color = lineA.UserData.OrigColor;
            lineA.UserData.ScaleMode = 'none';
            lineB.YData = lineB.UserData.OriginalYData;
            lineB.UserData.ScaleMode = 'none';
            legendData = legendHandle.UserData;
            legendData.Highlighted = gobjects(0);
            legendHandle.UserData = legendData;

            restore_plot2_signal_profile_state(legendHandle, profile);

            testCase.verifyEqual(lineA.YData, originalY .* 2);
            testCase.verifyEqual(lineB.YData, ...
                [100 * 4 / 6, 100 * 5 / 6, 100], 'AbsTol', 1e-12);
            testCase.verifyEqual(lineA.LineWidth, 4);
            testCase.verifyEqual(lineB.UserData.ScaleMode, 'auto');
            testCase.verifyEqual(legendHandle.UserData.Highlighted, lineA);
        end

        function deletesSignalFromPlotAndActiveProfile(testCase)
            figureHandle = figure('Visible', 'off');
            testCase.addTeardown(@delete_figure_if_valid, figureHandle);
            figureHandle.UserData = struct();
            axesHandle = axes('Parent', figureHandle);
            axesHandle.UserData = struct();
            logObj = struct('MSG', struct( ...
                'TimeS', [0; 1], 'A', [1; 2], 'B', [3; 4]));
            catalog = build_plot2_signal_catalog(logObj, []);
            legendHandle = legend(axesHandle, 'show');

            [~, unavailableIds, legendHandle] = apply_plot2_signal_profile( ...
                figureHandle, axesHandle, legendHandle, logObj, catalog, ...
                {'MSG.A', 'MSG.B'}, 0, []);
            testCase.verifyEmpty(unavailableIds);
            figureHandle.UserData.plot2ProfileName = 'Main';
            figureHandle.UserData.plot2ProfileSignals = {'MSG.A', 'MSG.B'};
            legendData = legendHandle.UserData;
            legendData.ScaleTarget = figureHandle.UserData.plot2ProfileLines(1);
            legendHandle.UserData = legendData;

            delete_plot2_profile_line(figureHandle, axesHandle, legendHandle, ...
                logObj, catalog, 0, []);

            profile = load_plot2_signal_profiles();
            testCase.verifyEqual(profile.signalIds, {'MSG.B'});
            remainingLines = figureHandle.UserData.plot2ProfileLines;
            testCase.verifyEqual(numel(remainingLines), 1);
            testCase.verifyEqual(remainingLines.UserData.SignalId, 'MSG.B');
        end
    end
end

function profile = make_profile(signalIds)
profile = struct( ...
    'name', 'Main', ...
    'signalIds', {signalIds}, ...
    'lineScaleSettings', { ...
    struct('signalId', {}, 'scaleMode', {}, 'scaleFactor', {})}, ...
    'highlightedSignalIds', {{}});
end

function restore_preferences(preferenceGroup, preferenceNames, ...
    hadPreferences, previousValues)
for preferenceIndex = 1:numel(preferenceNames)
    preferenceName = preferenceNames{preferenceIndex};
    if hadPreferences(preferenceIndex)
        setpref(preferenceGroup, preferenceName, previousValues{preferenceIndex});
    elseif ispref(preferenceGroup, preferenceName)
        rmpref(preferenceGroup, preferenceName);
    end
end
end

function delete_figure_if_valid(figureHandle)
if isgraphics(figureHandle)
    delete(figureHandle);
end
end

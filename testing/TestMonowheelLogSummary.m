classdef TestMonowheelLogSummary < matlab.unittest.TestCase
    methods (Test)
        function mapsRoverSpecificModeNumbers(testCase)
            testCase.verifyEqual(mode_name_from_id(2), ...
                'момент');
            testCase.verifyEqual(mode_name_from_id(17), ...
                'баланс');
            testCase.verifyEqual(mode_name_from_id(13), 'MODE_13');
        end

        function jumpAnalysisKeepsMarkdownRowColumnsAligned(testCase)
            row = table( ...
                {'20260820_sample.bin'}, 0, 3, {'TEST'}, {'TEST: 3s'}, ...
                0.1, 0.2, 0.3, 2, 5, {'3, 4'}, {'Wheel 3: 0.5 s'}, 1, ...
                {'1 likely jump(s) (heuristic: |a| < 3.0 m/s^2)'}, {''}, ...
                'VariableNames', {'FileName', 'StartTimeSec', 'DurationSec', ...
                'MainMode', 'ModeSummary', 'AvgSpeedMps', 'MaxSpeedMps', ...
                'MaxTurnRateRaw', 'WheelCount', 'WheelDistanceM', 'WheelIds', ...
                'WheelSlipSummary', 'JumpCount', 'JumpSummary', 'ChangedParams'});
            reportPath = [tempname '.md'];
            [reportDir, reportName, reportExt] = fileparts(reportPath);
            cleanup = onCleanup(@() delete(reportPath));

            write_summary_markdown(row, table(), reportDir, ...
                [reportName reportExt], table());
            reportText = fileread(reportPath);
            reportLines = regexp(reportText, '\r\n|\n|\r', 'split');
            reportRowIndex = find(contains(reportLines, 'likely jump'), 1);
            reportRow = reportLines{reportRowIndex};
            unescapedPipes = regexp(reportRow, '(?<!\\)\|', 'match');

            testCase.verifyEqual(numel(unescapedPipes), 17);
            testCase.verifyTrue(contains(reportRow, '\|a\|'));
            testCase.verifyTrue(contains(reportText, 'Jump detection method'));
            testCase.verifyTrue(contains(reportText, 'Wheel slip detection method'));
        end

        function plotsWheelTelemetryByWheelId(testCase)
            log = struct();
            log.WTLM = struct( ...
                'TimeS', [0; 1; 2; 3], ...
                'id', [3; 4; 3; 4], ...
                'Spd', [10; 20; 30; 40]);
            log.WIMU = struct( ...
                'TimeS', [0; 1; 2; 3], ...
                'id', [3; 4; 3; 4], ...
                'ax', [1; 2; 3; 4]);

            catalog = build_plot2_signal_catalog(log, []);
            wheelSignalId = 'Wheel3.WTLM.Spd';
            testCase.verifyTrue(any(strcmp({catalog.id}, wheelSignalId)));
            testCase.verifyTrue(any(strcmp({catalog.id}, 'Wheel4.WIMU.ax')));

            figureHandle = figure('Visible', 'off');
            cleanup = onCleanup(@() delete(figureHandle));
            axesHandle = axes('Parent', figureHandle);
            [lines, unavailableIds] = render_plot2_signal_profile( ...
                axesHandle, log, catalog, {wheelSignalId}, 0, []);

            testCase.verifyEmpty(unavailableIds);
            testCase.verifyEqual(lines(1).XData, [0 2]);
            testCase.verifyEqual(lines(1).YData, [10 30]);
        end

        function plotsImuFlightAssessmentSignals(testCase)
            log = struct();
            log.IMU = struct( ...
                'TimeS', [0; 0.1; 0.2], ...
                'AccX', [0; 0; 0], ...
                'AccY', [0; 0; 0], ...
                'AccZ', [9.81; 2; 16]);
            log.WIMU = struct( ...
                'TimeS', [0; 0.1; 0.2; 0.3], ...
                'id', [1; 2; 1; 2], ...
                'ax', [3; 30; 5; 40], ...
                'ay', [4; 0; 0; 0], ...
                'az', [0; 0; 12; 0]);

            catalog = build_plot2_signal_catalog(log, []);
            signalIds = { ...
                'Derived.IMU.AccelMagnitude', ...
                'Derived.IMU.LowAcceleration', ...
                'Wheel1.WIMU.AccelMagnitude'};
            for signalIndex = 1:numel(signalIds)
                testCase.verifyTrue(any(strcmp({catalog.id}, signalIds{signalIndex})));
            end

            figureHandle = figure('Visible', 'off');
            cleanup = onCleanup(@() delete(figureHandle));
            axesHandle = axes('Parent', figureHandle);
            hold(axesHandle, 'on');
            [lines, unavailableIds] = render_plot2_signal_profile( ...
                axesHandle, log, catalog, signalIds, 0, []);

            testCase.verifyEmpty(unavailableIds);
            testCase.verifyEqual(lines(1).YData, [9.81 2 16], 'AbsTol', 1e-10);
            testCase.verifyEqual(lines(2).YData, [0 1 0]);
            testCase.verifyEqual(lines(3).XData, [0 0.2], 'AbsTol', 1e-10);
            testCase.verifyEqual(lines(3).YData, [5 13], 'AbsTol', 1e-10);
        end

        function countsDistinctWheelsFromTelemetryIds(testCase)
            log = struct();
            log.WTLM = struct( ...
                'id', [3; 3; 4; 4], ...
                'Dist', [10; 13; 20; 25]);

            info = summarize_wheel_telemetry(log);

            testCase.verifyEqual(info.WheelCount, 2);
            testCase.verifyEqual(info.WheelDistanceM, 5);
            testCase.verifyEqual(info.WheelIds, '3, 4');
        end

        function findsSustainedWheelSpeedImbalance(testCase)
            time = (0:0.1:1.4)';
            wheel3Speed = 250 * ones(size(time));
            wheel3Speed(3:8) = 10;
            wheel3Speed(11:13) = 10;
            wheel4Speed = 300 * ones(size(time));
            log.WTLM = struct( ...
                'TimeS', [time; time], ...
                'id', [3 * ones(size(time)); 4 * ones(size(time))], ...
                'Spd', [wheel3Speed; wheel4Speed]);

            info = summarize_wheel_slip(log);

            testCase.verifyEqual(info.WheelIds, 3);
            testCase.verifyEqual(info.DurationsSec, 0.5, 'AbsTol', 1e-10);
            testCase.verifyEqual(info.EpisodeCounts, 1);
            testCase.verifyTrue(contains(info.Summary, 'Wheel 3: 0.5 s'));
        end

        function marksWheelSlipUnassessedWithoutMultipleWheels(testCase)
            log.WTLM = struct( ...
                'TimeS', [0; 1], ...
                'id', [3; 3], ...
                'Spd', [0; 250]);

            info = summarize_wheel_slip(log);

            testCase.verifyEmpty(info.WheelIds);
            testCase.verifyTrue(startsWith(info.Summary, 'Not assessed'));
        end

        function leavesWheelCountUnknownWithoutWheelTelemetry(testCase)
            info = summarize_wheel_telemetry(struct());

            testCase.verifyTrue(isnan(info.WheelCount));
            testCase.verifyTrue(isnan(info.WheelDistanceM));
            testCase.verifyTrue(contains(info.WheelIds, 'Unknown'));
        end

        function includesWheelDistanceWhenFilteringLogs(testCase)
            rec = struct( ...
                'FileName', 'moving-cart.bin', ...
                'DurationSec', 30, ...
                'MaxSpeedMps', 0.1, ...
                'MaxThrottleOut', 0, ...
                'WheelDistanceM', 5);

            testCase.verifyTrue(is_meaningful_log(rec, 20, 1, 0.05));
            rec.WheelDistanceM = 0.5;
            testCase.verifyFalse(is_meaningful_log(rec, 20, 1, 0.05));
        end

        function detectsFreeFallFollowedByImpact(testCase)
            timeValues = (0:0.02:2)';
            accZ = -9.81 * ones(size(timeValues));
            freeFall = timeValues >= 0.5 & timeValues <= 0.62;
            accZ(freeFall) = 0;
            accZ(timeValues == 0.64) = -20;
            log.IMU = struct( ...
                'TimeS', timeValues, ...
                'AccX', zeros(size(timeValues)), ...
                'AccY', zeros(size(timeValues)), ...
                'AccZ', accZ);

            [jumpCount, jumpSummary] = detect_log_jumps(log);

            testCase.verifyEqual(jumpCount, 1);
            testCase.verifyTrue(contains(jumpSummary, '0.5 s'));
        end

        function doesNotCountFreeFallWithoutImpactAsJump(testCase)
            timeValues = (0:0.02:2)';
            accZ = -9.81 * ones(size(timeValues));
            accZ(timeValues >= 0.5 & timeValues <= 0.62) = 0;
            log.IMU = struct( ...
                'TimeS', timeValues, ...
                'AccX', zeros(size(timeValues)), ...
                'AccY', zeros(size(timeValues)), ...
                'AccZ', accZ);

            [jumpCount, ~] = detect_log_jumps(log);

            testCase.verifyEqual(jumpCount, 0);
        end
    end
end

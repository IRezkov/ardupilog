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
                0.1, 0.2, 0.3, 2, 5, {'3, 4'}, 1, ...
                {'1 likely jump(s) (heuristic: |a| < 3.0 m/s^2)'}, {''}, ...
                'VariableNames', {'FileName', 'StartTimeSec', 'DurationSec', ...
                'MainMode', 'ModeSummary', 'AvgSpeedMps', 'MaxSpeedMps', ...
                'MaxTurnRateRaw', 'WheelCount', 'WheelDistanceM', 'WheelIds', ...
                'JumpCount', 'JumpSummary', 'ChangedParams'});
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

            testCase.verifyEqual(numel(unescapedPipes), 16);
            testCase.verifyTrue(contains(reportRow, '\|a\|'));
            testCase.verifyTrue(contains(reportText, 'Jump detection method'));
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

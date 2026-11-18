classdef TestCleanTimeOutliers < matlab.unittest.TestCase
    methods (Test)
        function preservesValidRowsAroundCorruptTimestamps(testCase)
            timeS = [0; 0.1; 0.2; 5.2; 5.3; 1.23057473e13; ...
                7.39578018e11; 5.4; 5.5];
            msg = LogMsgGroup(1, 'THR', 15, 'Qf', 'TimeUS,Value', 0);
            msg.TimeUS = timeS * 1e6;
            msg.Value = (1:numel(timeS))';

            msg = clean_time_outliers(msg, 10, false);

            testCase.verifyEqual(msg.TimeS, timeS([1:5 8:9]), ...
                'AbsTol', 1e-6);
            testCase.verifyEqual(msg.Value, [1:5 8:9]');
        end

        function preservesValidLongIntervals(testCase)
            timeS = [0; 0.1; 0.2; 5.2; 5.3; 20];
            msg = LogMsgGroup(1, 'THR', 15, 'Qf', 'TimeUS,Value', 0);
            msg.TimeUS = timeS * 1e6;
            msg.Value = (1:numel(timeS))';

            msg = clean_time_outliers(msg, 10, false);

            testCase.verifyEqual(msg.TimeS, timeS, 'AbsTol', 1e-6);
            testCase.verifyEqual(msg.Value, (1:numel(timeS))');
        end
    end
end

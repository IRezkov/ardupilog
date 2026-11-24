function write_summary_markdown(summaryTable, paramTable, outDir, filename, allSummaryTable)
    if (nargin < 4)
        filename = 'summary_report.md';
    end
    if nargin < 5
        allSummaryTable = table();
    end

    reportPath = fullfile(outDir, filename);
    fid = fopen(reportPath, 'w');
    if fid == -1
        error('Could not create summary report file %s', reportPath);
    end

    fprintf(fid, '# Log summary report\n\n');
    fprintf(fid, 'Generated for %d log(s).\n\n', height(summaryTable));

    fprintf(fid, '## Overview\n\n');
    fprintf(fid, '| Date | File | Start (s) | Duration (s) | Main mode | Mode summary | Avg speed (m/s) | Max speed (m/s) | Max turn rate | Wheel count | Wheel distance (m) | Wheel IDs | Jump count | Jump analysis | Params |\n');
    fprintf(fid, '| --- | --- | ---: | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: | --- | ---: | --- | --- |\n');

    for i = 1:height(summaryTable)
        row = summaryTable(i, :);
        dateValue = date_from_filename(row.FileName);
        fileName = safe_markdown_cell(row.FileName);
        startVal = format_numeric_markdown(row.StartTimeSec);
        modeName = safe_markdown_cell(row.MainMode);
        modeSummary = safe_markdown_cell(row.ModeSummary);
        durationVal = format_numeric_markdown(row.DurationSec);
        avgVal = format_numeric_markdown(row.AvgSpeedMps);
        maxVal = format_numeric_markdown(row.MaxSpeedMps);
        turnVal = format_numeric_markdown(row.MaxTurnRateRaw);
        wheelCountVal = format_numeric_markdown(row.WheelCount);
        wheelDistanceVal = format_numeric_markdown(row.WheelDistanceM);
        wheelIds = safe_markdown_cell(row.WheelIds);
        jumpCountVal = format_numeric_markdown(row.JumpCount);
        jumpSummary = safe_markdown_cell(row.JumpSummary);
        paramsText = safe_markdown_cell(row.ChangedParams);

        fprintf(fid, '| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n', ...
            dateValue, fileName, startVal, durationVal, modeName, modeSummary, avgVal, maxVal, ...
            turnVal, wheelCountVal, wheelDistanceVal, wheelIds, jumpCountVal, jumpSummary, paramsText);
    end

    fprintf(fid, '\n## Jump detection method\n\n');
    fprintf(fid, ['Jump detection is heuristic. The analyzer computes acceleration magnitude ' ...
        'from the selected IMU group (the group with the most complete samples). A likely ' ...
        'jump requires magnitude below 3 m/s^2 for at least 0.08 s, followed by magnitude ' ...
        'of at least 15 m/s^2 within 0.8 s. The reported time is the start of the low-' ...
        'acceleration interval, relative to boot time.\n\n']);
    fprintf(fid, ['This can miss jumps without both phases and can flag hard bumps or ' ...
        'other impacts. If usable IMU data is absent, the result is not assessed; ' ...
        'no detections do not prove that no jump occurred.\n']);

    fprintf(fid, '\n## Changed parameters\n\n');
    if isempty(paramTable)
        fprintf(fid, 'No changed parameters detected.\n');
    else
        fprintf(fid, '| Parameter | Value summary |\n');
        fprintf(fid, '| --- | --- |\n');

        for i = 1:height(paramTable)
            row = paramTable(i, :);
            nameCell = safe_markdown_cell(row.ParamName);
            valueCell = safe_markdown_cell(row.ValueSummary);
            fprintf(fid, '| %s | %s |\n', nameCell, valueCell);
        end
    end


    if ~isempty(allSummaryTable)
        fprintf(fid, '\n## All logs (before filtering)\n\n');
        fprintf(fid, '| Date | File | Start (s) | Duration (s) | Main mode | Mode summary | Avg speed (m/s) | Max speed (m/s) | Max turn rate | Wheel count | Wheel distance (m) | Wheel IDs | Jump count | Jump analysis | Params |\n');
        fprintf(fid, '| --- | --- | ---: | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: | --- | ---: | --- | --- |\n');

        for i = 1:height(allSummaryTable)
            row = allSummaryTable(i, :);
            dateValue = date_from_filename(row.FileName);
            fileName = safe_markdown_cell(row.FileName);
            startVal = format_numeric_markdown(row.StartTimeSec);
            modeName = safe_markdown_cell(row.MainMode);
            modeSummary = safe_markdown_cell(row.ModeSummary);
            durationVal = format_numeric_markdown(row.DurationSec);
            avgVal = format_numeric_markdown(row.AvgSpeedMps);
            maxVal = format_numeric_markdown(row.MaxSpeedMps);
            turnVal = format_numeric_markdown(row.MaxTurnRateRaw);
            wheelCountVal = format_numeric_markdown(row.WheelCount);
            wheelDistanceVal = format_numeric_markdown(row.WheelDistanceM);
            wheelIds = safe_markdown_cell(row.WheelIds);
            jumpCountVal = format_numeric_markdown(row.JumpCount);
            jumpSummary = safe_markdown_cell(row.JumpSummary);
            paramsText = safe_markdown_cell(row.ChangedParams);

            fprintf(fid, '| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n', ...
                dateValue, fileName, startVal, durationVal, modeName, modeSummary, avgVal, maxVal, ...
                turnVal, wheelCountVal, wheelDistanceVal, wheelIds, jumpCountVal, jumpSummary, paramsText);
        end
    end

    fclose(fid);
end

function dateValue = date_from_filename(fileName)
    fileNameText = char(string(fileName));
    tokens = regexp(fileNameText, '(\d{4})[-_](\d{1,2})[-_](\d{1,2})', 'tokens', 'once');
    if isempty(tokens)
        dateValue = 'Unknown';
        return;
    end

    dateValue = sprintf('%04d-%02d-%02d', str2double(tokens{1}), ...
        str2double(tokens{2}), str2double(tokens{3}));
end


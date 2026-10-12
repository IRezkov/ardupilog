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
    fprintf(fid, '| Date | File | Start (s) | Duration (s) | Main mode | Mode summary | Avg speed (m/s) | Max speed (m/s) | Max turn rate | Params |\n');
    fprintf(fid, '| --- | --- | ---: | ---: | --- | --- | ---: | ---: | ---: | --- |\n');

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
        paramsText = safe_markdown_cell(row.ChangedParams);

        fprintf(fid, '| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n', ...
            dateValue, fileName, startVal, durationVal, modeName, modeSummary, avgVal, maxVal, turnVal, paramsText);
    end


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
        fprintf(fid, '| Date | File | Start (s) | Duration (s) | Main mode | Mode summary | Avg speed (m/s) | Max speed (m/s) | Max turn rate | Params |\n');
        fprintf(fid, '| --- | --- | ---: | ---: | --- | --- | ---: | ---: | ---: | --- |\n');

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
            paramsText = safe_markdown_cell(row.ChangedParams);

            fprintf(fid, '| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n', ...
                dateValue, fileName, startVal, durationVal, modeName, modeSummary, avgVal, maxVal, turnVal, paramsText);
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

function s = safe_markdown_cell(value)
    if isempty(value)
        s = '-';
        return;
    end

    if iscell(value)
        s = strjoin(cellfun(@(x) safe_markdown_cell(x), value, 'UniformOutput', false), '; ');
        return;
    end

    if isnumeric(value) || islogical(value)
        s = format_numeric_markdown(value);
        return;
    end

    s = char(string(value));
    s = strrep(s, '\n', ' ');
    s = strrep(s, '|', '\\|');
end

function s = format_numeric_markdown(value)
    if isempty(value)
        s = '-';
        return;
    end

    if isnumeric(value) || islogical(value)
        if numel(value) ~= 1 || isnan(value)
            s = 'N/A';
            return;
        end
        s = num2str(value);
        return;
    end

    s = safe_markdown_cell(value);
end

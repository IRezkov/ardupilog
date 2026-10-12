function reportPath = create_mini_report(signalFigure, mapFigure, log, outputDir, modeLabel, modeStartTime)
    if nargin < 4 || isempty(outputDir)
        outputDir = pwd;
    end
    if nargin < 5
        modeLabel = '';
    end
    if nargin < 6 || isempty(modeStartTime)
        modeStartTime = NaN;
    end
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    modeFileName = extract_mode_name(modeLabel);
    if isempty(modeFileName)
        modeFileName = 'mode_unknown';
    end
    signalAxes = findobj(signalFigure, 'Type', 'axes');
    if isempty(signalAxes)
        centerTime = NaN;
    else
        timeRange = get(signalAxes(1), 'XLim');
        centerTime = mean(timeRange);
    end
    if isfinite(centerTime)
        timeFileName = sprintf('t_%0.1fs', centerTime);
    else
        timeFileName = 't_unknown';
    end
    reportBase = fullfile(outputDir, ['mini_report_' safe_file_name(get_log_name(log)) '_' ...
        modeFileName '_' timeFileName]);
    signalImage = [tempname(outputDir) '_signals.png'];
    mapImage = [tempname(outputDir) '_map.png'];
    reportPath = [reportBase '.mhtml'];

    exportgraphics(signalFigure, signalImage, 'Resolution', 150);
    exportgraphics(mapFigure, mapImage, 'Resolution', 150);
    signalInfo = imfinfo(signalImage);
    mapInfo = imfinfo(mapImage);
    targetImageHeight = min(signalInfo.Height, mapInfo.Height);
    signalDisplayWidth = signalInfo.Width * targetImageHeight / signalInfo.Height;
    mapDisplayWidth = mapInfo.Width * targetImageHeight / mapInfo.Height;
    reportWidth = ceil(signalDisplayWidth + mapDisplayWidth + 4);

    fid = fopen(reportPath, 'w');
    if fid == -1
        error('Could not create mini-report %s', reportPath);
    end

    boundary = '----=_MissionPlannerMiniReport_7F3A';
    fprintf(fid, 'MIME-Version: 1.0\r\n');
    fprintf(fid, 'Content-Type: multipart/related; boundary="%s"\r\n\r\n', boundary);
    fprintf(fid, '--%s\r\n', boundary);
    fprintf(fid, 'Content-Type: text/html; charset="utf-8"\r\n');
    fprintf(fid, 'Content-Location: report.html\r\n\r\n');
    fprintf(fid, '<!doctype html><html><head><meta charset="utf-8">');
    fprintf(fid, '<title>Mission Planner mini report</title>');
    fprintf(fid, '%s\r\n', '<style>');
    fprintf(fid, ':root { --table-width-percent: 28%%; --report-width: %dpx; }\r\n', reportWidth);
    fprintf(fid, '%s\r\n', 'body { font-family: Arial, sans-serif; margin: 16px; color: #222; }');
    fprintf(fid, '%s\r\n', 'h1 { font-size: 20px; margin: 0 0 6px; }');
    fprintf(fid, '%s\r\n', 'h2 { font-size: 15px; margin: 12px 0 6px; }');
    fprintf(fid, '%s\r\n', '.reportFrame { display: block; width: min(var(--report-width), calc(100vw - 32px)); max-width: calc(100vw - 32px); }');
    fprintf(fid, '%s\r\n', '.images { display: flex; width: 100%%; overflow: hidden; align-items: flex-start; }');
    fprintf(fid, '%s\r\n', '.images img { display: block; flex: 0 0 50%%; width: 50%%; max-width: 50%%; height: auto; box-sizing: border-box; border: 1px solid #bbb; }');
    fprintf(fid, '%s\r\n', '.parameterTables { display: flex; gap: 12px; align-items: flex-start; width: 100%%; }');
    fprintf(fid, '%s\r\n', '.parameterTables table { flex: 0 0 var(--table-width-percent); width: var(--table-width-percent); max-width: none; border-collapse: collapse; table-layout: fixed; font-size: 18px; line-height: 1.2; overflow-wrap: anywhere; }');
    fprintf(fid, '%s\r\n', 'th, td { border: 1px solid #aaa; padding: 5px 7px; text-align: left; vertical-align: top; overflow-wrap: anywhere; }');
    fprintf(fid, '%s\r\n', 'th { background: #eee; font-weight: bold; }');
    fprintf(fid, '%s\r\n', 'td:nth-child(1), th:nth-child(1) { width: 58%%; }');
    fprintf(fid, '%s\r\n', 'td:nth-child(2), th:nth-child(2) { width: 27%%; }');
    fprintf(fid, '%s\r\n', 'td:nth-child(3), th:nth-child(3) { width: 15%%; }');
    fprintf(fid, '%s\r\n', '</style>');
    fprintf(fid, '%s\r\n', '</head>');
    fprintf(fid, '%s\r\n', '<body>');
    fprintf(fid, '%s\r\n', '<h1>Mission Planner mini report</h1>');
    fprintf(fid, '<div><b>Log:</b> %s<br><b>Mode:</b> %s</div>\r\n', ...
        html_escape(get_log_name(log)), html_escape(modeLabel));
    fprintf(fid, '%s\r\n', '<div class="reportFrame">');
    fprintf(fid, '%s\r\n', '  <div class="images">');
    fprintf(fid, '    <img id="signalImage" src="cid:signals-image" alt="Signal plots" width="%d">\r\n', ceil(signalDisplayWidth));
    fprintf(fid, '    <img id="mapImage" src="cid:map-image" alt="Map" width="%d">\r\n', ceil(mapDisplayWidth));
    fprintf(fid, '%s\r\n', '  </div>');
    fprintf(fid, '%s\r\n', '<h2>Selected parameters</h2>');

    paramNames = read_param_names();
    paramMap = extract_last_param_map(log, modeStartTime);
    changedParamNames = read_mode_changed_param_names(outputDir, get_log_name(log), modeLabel);
    fprintf(fid, '%s\r\n', '  <div class="parameterTables">');
    paramCount = numel(paramNames);
    for partIndex = 1:3
        partStart = floor((partIndex - 1) * paramCount / 3) + 1;
        partEnd = floor(partIndex * paramCount / 3);
        fprintf(fid, '%s\r\n', '    <table>');
        fprintf(fid, '%s\r\n', '      <tr><th>Parameter</th><th>Value</th><th>Units</th></tr>');
        for i = partStart:partEnd
            name = paramNames{i};
            if isKey(paramMap, name)
                [value, units] = format_param_value(paramMap(name), name);
            else
                value = 'not found';
                units = get_param_units(name);
            end
            nameHtml = html_escape(name);
            valueHtml = html_escape(value);
            if ismember(upper(name), changedParamNames)
                nameHtml = ['<b>' nameHtml '</b>'];
                valueHtml = ['<b>' valueHtml '</b>'];
            end
            fprintf(fid, '      <tr><td>%s</td><td>%s</td><td>%s</td></tr>\r\n', ...
                nameHtml, valueHtml, html_escape(units));
        end
        fprintf(fid, '%s\r\n', '    </table>');
    end
    fprintf(fid, '%s\r\n', '  </div>');
    fprintf(fid, '%s\r\n', '</div>');
    fprintf(fid, '%s\r\n', '</body>');
    fprintf(fid, '%s\r\n', '</html>');
    write_mime_image(fid, boundary, signalImage, 'signals.png', 'signals-image');
    write_mime_image(fid, boundary, mapImage, 'map.png', 'map-image');
    fprintf(fid, '--%s--\r\n', boundary);
    fclose(fid);
    delete(signalImage);
    delete(mapImage);
    fprintf('Mini-report written to:\n  %s\n', reportPath);
end

function write_mime_image(fid, boundary, imagePath, contentLocation, contentId)
    imageFile = fopen(imagePath, 'rb');
    if imageFile == -1
        error('Could not read report image %s', imagePath);
    end
    cleanup = onCleanup(@() fclose(imageFile));
    imageBytes = fread(imageFile, Inf, '*uint8');
    encoded = matlab.net.base64encode(imageBytes);
    fprintf(fid, '\r\n--%s\r\n', boundary);
    fprintf(fid, 'Content-Type: image/png\r\n');
    fprintf(fid, 'Content-Transfer-Encoding: base64\r\n');
    fprintf(fid, 'Content-ID: <%s>\r\n', contentId);
    fprintf(fid, 'Content-Location: %s\r\n\r\n', contentLocation);
    for startIndex = 1:76:numel(encoded)
        endIndex = min(startIndex + 75, numel(encoded));
        fprintf(fid, '%s\r\n', encoded(startIndex:endIndex));
    end
end

function name = get_log_name(log)
    name = '';
    if isprop(log, 'fileName')
        name = char(string(log.fileName));
    end
end

function name = safe_file_name(value)
    name = regexprep(char(string(value)), '[^A-Za-z0-9_.-]', '_');
    if isempty(name)
        name = 'log';
    end
end

function name = extract_mode_name(modeLabel)
    modeText = upper(char(string(modeLabel)));
    modeNames = {'MANUAL', 'ACRO', 'STEERING', 'HOLD', 'LOITER', ...
        'FOLLOW', 'SIMPLE', 'DOCK', 'CIRCLE', 'AUTO', 'SMART_RTL', ...
        'RTL', 'GUIDED', 'INITIALISING'};
    name = '';
    for i = 1:numel(modeNames)
        if contains(modeText, modeNames{i})
            name = modeNames{i};
            return;
        end
    end
    if isempty(name)
        name = '';
    end
end

function name = get_filename(path)
    [~, name, ext] = fileparts(path);
    name = [name ext];
end

function names = read_param_names()
    configPath = fullfile(fileparts(mfilename('fullpath')), 'mini_report_params.txt');
    lines = readlines(configPath);
    lines = strtrim(lines);
    lines = lines(lines ~= "" & ~startsWith(lines, "#"));
    names = cellstr(lines);
end

function changedNames = read_mode_changed_param_names(outputDir, logName, modeLabel)
    changedNames = strings(0, 1);
    summaryPath = fullfile(outputDir, 'summary_report.md');
    if ~isfile(summaryPath)
        return;
    end

    lines = readlines(summaryPath);
    expectedFile = char(string(logName));
    expectedMode = extract_mode_name(modeLabel);
    inOverview = false;
    for lineIndex = 1:numel(lines)
        line = strtrim(char(lines(lineIndex)));
        if startsWith(line, '| Date | File |')
            inOverview = true;
            continue;
        end
        if ~inOverview || isempty(line) || ~startsWith(line, '|')
            if inOverview && ~isempty(line)
                break;
            end
            continue;
        end
        if contains(line, '| ---')
            continue;
        end

        columns = regexp(line, '^\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*$', 'tokens', 'once');
        if isempty(columns) || ~strcmp(strtrim(columns{2}), expectedFile) || ...
                ~strcmpi(strtrim(columns{5}), expectedMode)
            continue;
        end

        paramText = strtrim(columns{10});
        paramTokens = regexp(paramText, '([A-Za-z][A-Za-z0-9_.]*)\s*:', 'tokens');
        if ~isempty(paramTokens)
            changedNames = upper(string(cellfun(@(token) token{1}, paramTokens, ...
                'UniformOutput', false)));
        end
        return;
    end
end

function [text, units] = format_param_value(value, name)
    units = get_param_units(name);
    if strcmp(units, 'km/h') && isnumeric(value)
        value = double(value) * 3.6;
    end
    if isnumeric(value) || islogical(value)
        if isscalar(value)
            text = num2str(double(value), '%.6g');
        else
            text = mat2str(value);
        end
    else
        text = char(string(value));
    end
end

function units = get_param_units(name)
    if contains(upper(name), 'SPEED')
        units = 'km/h';
    else
        units = '-';
    end
end

function text = html_escape(value)
    text = char(string(value));
    text = strrep(text, '&', '&amp;');
    text = strrep(text, '<', '&lt;');
    text = strrep(text, '>', '&gt;');
    text = strrep(text, '"', '&quot;');
end


function save_mini_report_callback(signalFigure, mapFigure, log, outputDir, modeLabel, modeStartTime)
    try
        reportPath = create_mini_report(signalFigure, mapFigure, log, outputDir, modeLabel, modeStartTime);
        show_save_notice(signalFigure, sprintf('Файл сохранён: %s', get_filename(reportPath)), false);
    catch exception
        show_save_notice(signalFigure, ['Ошибка сохранения: ' exception.message], true);
        rethrow(exception);
    end
end

function show_save_notice(signalFigure, message, isError)
    if isempty(signalFigure) || ~isvalid(signalFigure)
        return;
    end

    oldNotice = findobj(signalFigure, 'Tag', 'MiniReportSaveNotice');
    delete(oldNotice);
    notice = uicontrol(signalFigure, 'Style', 'text', ...
        'Tag', 'MiniReportSaveNotice', ...
        'String', message, ...
        'Units', 'normalized', ...
        'Position', [0.09 0.905 0.42 0.04], ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', ternary_color(isError), ...
        'ForegroundColor', [0.05 0.05 0.05]);
    cleanupTimer = timer('ExecutionMode', 'singleShot', 'StartDelay', 4, ...
        'TimerFcn', @(~, ~) delete_notice(notice));
    start(cleanupTimer);
end

function delete_notice(notice)
    if ~isempty(notice) && isvalid(notice)
        delete(notice);
    end
end

function color = ternary_color(isError)
    if isError
        color = [1.0 0.8 0.8];
    else
        color = [0.75 0.95 0.75];
    end
end

function name = get_filename(path)
    [~, baseName, extension] = fileparts(path);
    name = [baseName extension];
end
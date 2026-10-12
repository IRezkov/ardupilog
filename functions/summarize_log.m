function summaryTable = summarize_log(logFiles, outDir)
    if nargin < 2 || isempty(outDir)
        outDir = pwd;
    end

    summaryTable = table();
    if isempty(logFiles)
        return;
    end

    processedLogs = {};
    paramMaps = {};

    for i = 1:numel(logFiles)
        try
            log = Ardupilog(logFiles{i});
            if ismethod(log, 'deleteEmptyMsgs')
                log = log.deleteEmptyMsgs;
            end
            rec = summarize_single_log(log, logFiles{i});
            processedLogs{end + 1} = rec;
            paramMaps{end + 1} = extract_last_param_map(log);
        catch
            continue;
        end
    end

    if isempty(processedLogs)
        return;
    end

    summaryTable = struct2table(processedLogs(:));
    summaryTable = attach_changed_params_to_summary(summaryTable, paramMaps);
    if ~isempty(outDir)
        if ~exist(outDir, 'dir')
            mkdir(outDir);
        end
        write_summary_markdown(summaryTable, build_changed_param_table(paramMaps), outDir);
    end
end

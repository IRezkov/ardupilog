function fileList = sort_bin_files_by_start_time(fileList)
    if isempty(fileList)
        return;
    end

    timestamps = zeros(numel(fileList), 1);
    for i = 1:numel(fileList)
        timestamps(i) = log_start_epoch(fileList{i});
    end

    [~, order] = sort(timestamps);
    fileList = fileList(order);

    baseNames = cellfun(@(p) lower(basename_from_path(p)), fileList, 'UniformOutput', false);
    [~, keepIdx] = unique(baseNames, 'stable');
    fileList = fileList(sort(keepIdx));
end
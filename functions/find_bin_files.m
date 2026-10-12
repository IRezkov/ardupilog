function fileList = find_bin_files(rootDir, searchSubdirs)
    if nargin < 2 || isempty(searchSubdirs)
        searchSubdirs = true;
    end

    fileList = {};
    allFiles = dir(rootDir);
    if searchSubdirs
        for i = 1:numel(allFiles)
            if allFiles(i).isdir && ~strcmp(allFiles(i).name, '.') && ~strcmp(allFiles(i).name, '..')
                subFiles = find_bin_files(fullfile(rootDir, allFiles(i).name), true);
                fileList = [fileList, subFiles];
            end
        end
    end

    allBin = dir(fullfile(rootDir, '*.bin'));
    for i = 1:numel(allBin)
        fileList{end + 1} = fullfile(rootDir, allBin(i).name);
    end

    if isempty(fileList)
        return;
    end

    normalizedPaths = cellfun(@(p) lower(strtrim(p)), fileList, 'UniformOutput', false);
    [~, uniqueIdx] = unique(normalizedPaths, 'stable');
    fileList = fileList(sort(uniqueIdx));
end

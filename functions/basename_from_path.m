function base = basename_from_path(p)
    [~, name, ext] = fileparts(p);
    base = [name ext];
end
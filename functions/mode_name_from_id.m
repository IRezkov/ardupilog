function name = mode_name_from_id(modeId)
    modeMap = {
        'MANUAL';
        'ACRO';
        '2';          % 2 — пропущен в исходном enum
        'STEERING';
        'HOLD';
        'LOITER';
        'FOLLOW';
        'SIMPLE';
        'DOCK';
        'CIRCLE';
        'AUTO';
        'RTL';
        'SMART_RTL';
        '13';    
        '14'; % 13,14 — пропущены
        'GUIDED';
        'INITIALISING'
    };

    idx = modeId + 1;
    if idx >= 1 && idx <= numel(modeMap)
        name = modeMap{idx};
    else
        name = sprintf('MODE_%d', modeId);
    end
end
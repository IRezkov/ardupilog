function name = mode_name_from_id(modeId)
    modeMap = {
        'MANUAL';
        'ACRO';
        'момент';
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
        '';
        '';
        'GUIDED';
        'INITIALISING';
        'баланс'
    };

    if isscalar(modeId) && isfinite(modeId) && modeId == fix(modeId) && ...
            modeId >= 0 && modeId < numel(modeMap) && ...
            ~isempty(modeMap{modeId + 1})
        idx = modeId + 1;
        name = modeMap{idx};
    else
        name = sprintf('MODE_%d', modeId);
    end
end
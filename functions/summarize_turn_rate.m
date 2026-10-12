function maxTurnRate = summarize_turn_rate(log)
    maxTurnRate = NaN;
    sterObj = get_field_value(log, 'STER');
    turnRate = get_field_value(sterObj, 'TurnRate');
    if isempty(turnRate)
        return;
    end

    vals = double(turnRate);
    vals = vals(:);
    vals = vals(~isnan(vals) & isfinite(vals));
    if isempty(vals)
        return;
    end
    maxTurnRate = max(abs(vals));
end
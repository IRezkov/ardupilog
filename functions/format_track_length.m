function text = format_track_length(lengthMeters)
%FORMAT_TRACK_LENGTH Format a distance for compact UI display.

if ~isfinite(lengthMeters)
    text = 'unavailable';
elseif abs(lengthMeters) >= 1000
    text = sprintf('%.2f km', lengthMeters / 1000);
else
    text = sprintf('%.1f m', lengthMeters);
end
end

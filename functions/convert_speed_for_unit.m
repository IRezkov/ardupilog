function converted = convert_speed_for_unit(speedMps, unitName)
%CONVERT_SPEED_FOR_UNIT Convert stored metres-per-second values for display.

converted = double(speedMps);
if nargin < 2
    unitName = 'km/h';
end
if strcmp(unitName, 'km/h')
    converted = converted * 3.6;
end
end

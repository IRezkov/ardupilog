function signal = read_plot2_rudder_signal(logObj, sutsField, fallbackGroup, t0)
signal = read_plot2_actuator_signal(logObj, 'SUTS', {sutsField}, t0);
if ~isempty(signal.time)
    if strcmp(sutsField, 'LPos')
        signal.values = -signal.values;
    end
else
    signal = read_plot2_actuator_signal( ...
        logObj, fallbackGroup, {'Act', 'Cmd'}, t0);
end
end

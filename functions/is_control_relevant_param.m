function keep = is_control_relevant_param(name)
    if isempty(name)
        keep = false;
        return;
    end

    n = upper(char(string(name)));

    ignorePatterns = {'BARO', 'STAT_', 'COMPASS', 'MAG_', 'INS_', 'RCIN', 'RCOU', 'RSSI', 'BATT_', 'BAT_' , 'SYS_', 'LOG_', 'FS_', 'IMU', 'EKF', 'SCHED', 'PID_' };
    for p = 1:numel(ignorePatterns)
        if contains(n, ignorePatterns{p})
            keep = false;
            return;
        end
    end

    relevantPrefixes = {'ATC_', 'GPS', 'ACRO', 'ANK', 'WP', 'PILOT_', 'CRUISE_', 'THR_', 'SERVO_', 'STEER', 'TURN', 'WPNAV_', 'NAV_', 'L1_', 'PSC_', 'ANGLE', 'RATE', 'MOT_', 'MAV_'};

    keep = false;
    for p = 1:numel(relevantPrefixes)
        if startsWith(n, relevantPrefixes{p})
            keep = true;
            return;
        end
    end
end

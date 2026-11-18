function label = speed_unit_label(unitName)
if strcmp(unitName, 'm/s')
    label = 'Скорость, м/с';
else
    label = 'Скорость, км/ч';
end
end

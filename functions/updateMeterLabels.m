% function updateMeterLabels(gax, refLat, refLng)
%     latTicks = gax.LatitudeAxis.TickValues;
%     lonTicks = gax.LongitudeAxis.TickValues;
% 
%     latMeters = round((latTicks - refLat) * 111320);
%     lonMeters = round((lonTicks - refLng) * 111320 * cosd(refLat));
% 
%     gax.LatitudeAxis.TickLabels  = string(latMeters);
%     gax.LongitudeAxis.TickLabels = string(lonMeters);
% end
function updateMeterLabels(gax, refLat, refLng)
% disp('updateMeterLabels called');


    % Получаем текущие деления в градусах
    latTicks = gax.LatitudeAxis.TickValues;
    lonTicks = gax.LongitudeAxis.TickValues;

    % Переводим в метры
    latMeters = round((latTicks - refLat) * 111320);
    lonMeters = round((lonTicks - refLng) * 111320 * cosd(refLat));

    % Записываем как текстовые подписи
    gax.LatitudeAxis.TickLabels = string(latMeters);
    gax.LongitudeAxis.TickLabels = string(lonMeters);
end

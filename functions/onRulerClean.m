% --- Вложенная функция ---
function onRulerClean(gax)
    try
        latTicks = gax.LatitudeAxis.TickValues;
        lonTicks = gax.LongitudeAxis.TickValues;
        
        % Запоминаем предыдущие деления
        prevLat = gax.UserData.prevLatTicks;
        prevLon = gax.UserData.prevLonTicks;
        
        % Если деления не изменились — выходим, ничего не делаем
        if isequal(latTicks, prevLat) && isequal(lonTicks, prevLon)
            return;
        end
        
        % Сохраняем новые деления
        gax.UserData.prevLatTicks = latTicks;
        gax.UserData.prevLonTicks = lonTicks;
        
        % Обновляем подписи
        updateMeterLabels(gax, gax.UserData.refLat, gax.UserData.refLng);
    catch ME
        warning('onRulerClean: %s', ME.message);
    end
end

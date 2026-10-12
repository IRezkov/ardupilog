function set_value_in_map(mapObj, keyName, value, textValue, listCell)
    if ~isKey(mapObj, keyName)
        listCell{end + 1} = textValue;
        mapObj(keyName) = value;
    end
end

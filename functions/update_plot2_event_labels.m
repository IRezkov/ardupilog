function update_plot2_event_labels(signalAxes, eventTimes, eventLabels, verticalAnchor)
%UPDATE_PLOT2_EVENT_LABELS Position event labels at the top or bottom of axes.

if ~isgraphics(signalAxes, 'axes') || isempty(eventLabels)
    return;
end
if ~any(strcmp(verticalAnchor, {'top', 'bottom'}))
    error('plot2:InvalidEventLabelAnchor', ...
        'verticalAnchor must be ''top'' or ''bottom''.');
end

yLimits = sort(signalAxes.YLim);
xLimits = sort(signalAxes.XLim);
yRange = diff(yLimits);
xRange = diff(xLimits);
if any(~isfinite([yLimits, xLimits])) || yRange <= 0 || xRange <= 0
    return;
end

labelCount = min(numel(eventTimes), numel(eventLabels));
intervals = nan(labelCount, 2);
labelHeights = nan(labelCount, 1);
horizontalPadding = 0.003 * xRange;
for i = 1:labelCount
    label = eventLabels(i);
    if ~isgraphics(label, 'text')
        continue;
    end

    isVisible = isfinite(eventTimes(i)) && ...
        eventTimes(i) >= xLimits(1) && eventTimes(i) <= xLimits(2);
    if ~isVisible
        label.Visible = 'off';
        continue;
    end

    label.VerticalAlignment = verticalAnchor;
    label.HorizontalAlignment = 'left';
    if eventTimes(i) > xLimits(1) + xRange / 2
        label.HorizontalAlignment = 'right';
    end
    label.Visible = 'on';
    extent = label.Extent;
    intervals(i, :) = [extent(1) - horizontalPadding, ...
        extent(1) + extent(3) + horizontalPadding];
    labelHeights(i) = extent(4);
end

visibleIndices = find(isfinite(intervals(:, 1)));
if isempty(visibleIndices)
    return;
end
[~, order] = sort(intervals(visibleIndices, 1));
visibleIndices = visibleIndices(order);

laneEnds = zeros(0, 1);
labelLanes = zeros(labelCount, 1);
for i = 1:numel(visibleIndices)
    labelIndex = visibleIndices(i);
    lane = find(intervals(labelIndex, 1) > laneEnds, 1);
    if isempty(lane)
        lane = numel(laneEnds) + 1;
        laneEnds(lane, 1) = -Inf;
    end
    laneEnds(lane) = intervals(labelIndex, 2);
    labelLanes(labelIndex) = lane;
end

rowHeight = max(labelHeights(visibleIndices));
if ~isfinite(rowHeight) || rowHeight <= 0
    rowHeight = 0.04 * yRange;
end
topMargin = 0.2 * rowHeight;
rowSpacing = 1.25 * rowHeight;
for i = 1:numel(visibleIndices)
    labelIndex = visibleIndices(i);
    label = eventLabels(labelIndex);
    position = label.Position;
    if strcmp(verticalAnchor, 'top')
        position(2) = yLimits(2) - topMargin - ...
            (labelLanes(labelIndex) - 1) * rowSpacing;
    else
        position(2) = yLimits(1) + topMargin + ...
            (labelLanes(labelIndex) - 1) * rowSpacing;
    end
    label.Position = position;
end
end

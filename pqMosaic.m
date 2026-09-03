function mosaic = pqMosaic(plane,targetPixels)
% pqMosaic A grid of tiles taken from across a plane, laid into one image
%
%   Noise is measured from neighbouring pixels, so it cannot be measured on
%   a thinned copy of a scan the way a median or a percentile can. Taking a
%   grid of tiles keeps neighbours together while cutting the work, and
%   spreads the sample across the whole scan rather than trusting one corner
%   of it to be typical. The few seams where tiles meet are a fraction of a
%   percent of the pixels, and a median does not notice them.
if(nargin < 2)
    targetPixels = 1e6;
end
[numberRows,numberColumns] = size(plane);
if(numel(plane) <= targetPixels)
    mosaic = plane;
    return
end
tilesPerSide = 4;
tileRows = max(3,floor(sqrt(targetPixels/tilesPerSide^2)));
tileRows = min(tileRows,floor(numberRows/tilesPerSide));
tileColumns = min(tileRows,floor(numberColumns/tilesPerSide));
if(tileRows < 3 || tileColumns < 3)
    mosaic = plane;
    return
end
rowStep = floor((numberRows-tileRows)/(tilesPerSide-1));
columnStep = floor((numberColumns-tileColumns)/(tilesPerSide-1));
mosaic = zeros(tilesPerSide*tileRows,tilesPerSide*tileColumns);
for tileRow = 1:tilesPerSide
    for tileColumn = 1:tilesPerSide
        firstRow = 1+(tileRow-1)*rowStep;
        firstColumn = 1+(tileColumn-1)*columnStep;
        mosaic((tileRow-1)*tileRows+(1:tileRows), ...
            (tileColumn-1)*tileColumns+(1:tileColumns)) = ...
            plane(firstRow-1+(1:tileRows),firstColumn-1+(1:tileColumns));
    end
end
end

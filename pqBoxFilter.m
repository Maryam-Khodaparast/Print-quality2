function filtered = pqBoxFilter(plane,boxSize)
% pqBoxFilter Box average with replicated edges, no toolbox needed
%
%   Averaging over a box cuts white noise by the size of the box while
%   leaving anything larger than the box alone, which is how print that is
%   too faint to see in a single pixel is still found: a feature covering
%   thousands of pixels does not have to clear the noise pixel by pixel.
plane = double(plane);
half = floor(boxSize/2);
if(half < 1)
    filtered = plane;
    return
end
[numberRows,numberColumns] = size(plane);
rowIndex = [ones(1,half) 1:numberRows numberRows*ones(1,half)];
columnIndex = [ones(1,half) 1:numberColumns numberColumns*ones(1,half)];
boxSize = 2*half+1;
filtered = conv2(ones(boxSize,1)/boxSize,ones(1,boxSize)/boxSize, ...
    plane(rowIndex,columnIndex),'valid');
end

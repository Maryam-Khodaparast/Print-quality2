function coverage = pqRasteriseRects(rects,imageSize,blurSigma)
% pqRasteriseRects Ink area of each pixel covered by a list of rectangles
%
%   coverage = pqRasteriseRects(rects,imageSize) where rects is an N by 4
%   matrix of [rowFirst rowLast columnFirst columnLast] continuous edges.
%   The pixel with index c covers c-0.5 to c+0.5, so a rectangle covering
%   columns a to b in full has edges a-0.5 and b+0.5.
%
%   coverage = pqRasteriseRects(rects,imageSize,blurSigma) blurs the ink
%   with a Gaussian of that width before the pixel collects it.
%
%   Both are integrated exactly rather than sampled, so a rectangle moved by
%   a fraction of a pixel changes the coverage of its edge pixels by exactly
%   that fraction. That is the only honest way to test an analyser that
%   claims a hundredth of a pixel.
%
%   The blur has to be done this way round, and not by rasterising the ink
%   and then filtering the image. A camera blurs the scene and then samples
%   it; filtering afterwards samples the scene and then blurs it, which is a
%   different thing. The first moment of a sampled hard edged rectangle is
%   not its centre - the rectangle's edges land inside pixels, and the pixel
%   collects the whole of itself at its own centre - and a symmetric filter
%   applied afterwards leaves that error exactly where it was. On a 3.8 pixel
%   wide feature it is 0.02 pixels, which is 0.7 microns at 720 dpi, and it
%   changes with the subpixel position of the ink, so it looks like an
%   analyser that cannot measure a fraction of a pixel. Blurring first
%   removes it, because the blurred edge is spread over several pixels and
%   its first moment survives the sampling.
if(nargin < 3)
    blurSigma = 0;
end
coverage = zeros(imageSize);
margin = ceil(4*blurSigma)+1;
for k = 1:size(rects,1)
    rowFirst = rects(k,1); rowLast = rects(k,2);
    columnFirst = rects(k,3); columnLast = rects(k,4);
    if(rowLast <= rowFirst || columnLast <= columnFirst)
        continue
    end
    rows = max(1,floor(rowFirst+0.5)-margin):min(imageSize(1),ceil(rowLast+0.5)+margin);
    columns = max(1,floor(columnFirst+0.5)-margin):min(imageSize(2),ceil(columnLast+0.5)+margin);
    if(isempty(rows) || isempty(columns))
        continue
    end
    weightRows = pqSpanWeight(rows,rowFirst,rowLast,blurSigma);
    weightColumns = pqSpanWeight(columns,columnFirst,columnLast,blurSigma);
    coverage(rows,columns) = coverage(rows,columns) ...
        +weightRows(:)*weightColumns(:)';
end
end

function weight = pqSpanWeight(index,first,last,sigma)
% How much of the pixel at index is covered by the span first to last, after
% the span has been blurred by sigma.
if(sigma <= 0)
    weight = max(0,min(last,index+0.5)-max(first,index-0.5));
    return
end
weight = pqRamp(index+0.5-first,sigma)-pqRamp(index-0.5-first,sigma) ...
    -pqRamp(index+0.5-last,sigma)+pqRamp(index-0.5-last,sigma);
weight = max(0,weight);
end

function value = pqRamp(t,sigma)
% The integral of a blurred step, which is what a pixel sees of one edge.
scaled = t/sigma;
value = t.*(0.5*erfc(-scaled/sqrt(2)))+sigma*exp(-0.5*scaled.^2)/sqrt(2*pi);
end

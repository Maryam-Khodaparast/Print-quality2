function dense = pqDenseRegions(mask,boxSize,minimumDensity)
% pqDenseRegions Drop the isolated pixels of a mask and keep the packed ones
%
%   dense = pqDenseRegions(mask,boxSize,minimumDensity) keeps the true
%   pixels of mask that have at least minimumDensity of their boxSize
%   square neighbourhood also true.
%
%   This is what tells print from speckle. Dust on the glass, a hot pixel
%   and a noise spike are all isolated: a couple of pixels with nothing
%   around them. Print is packed, whether it is a solid, a two pixel line or
%   a screened tint whose dots sit a few pixels apart. Judging the
%   neighbourhood rather than filtering the image keeps halftone dots, which
%   a median filter would take out along with the dust.
if(nargin < 2)
    boxSize = 11;
end
if(nargin < 3)
    minimumDensity = 0.05;
end
mask = logical(mask);
if(~any(mask(:)))
    dense = mask;
    return
end
density = conv2(ones(boxSize,1)/boxSize,ones(1,boxSize)/boxSize, ...
    double(mask),'same');
dense = mask & (density >= minimumDensity);
end

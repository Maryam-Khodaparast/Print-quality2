function [imageGreyscale,mask,paper] = pqLegacySelectChannel(imageIn)
% pqLegacySelectChannel The original mask pipeline, kept as the baseline
%
%   Identical to the original selectChannel except that the histogram is
%   counted with accumarray instead of histcounts, so that it also runs
%   under Octave, and that it calls pqLegacyFindChannel2Use.
if(isa(imageIn,'uint16'))
    imageIn = uint8(double(imageIn)/257);
end
imageGreyscale = double(pqLegacyFindChannel2Use(imageIn));
pixelCount = accumarray(min(256,max(1,round(imageGreyscale(:))+1)),1,[256 1]);
[~,maxBin] = max(pixelCount(1:256));
paper = maxBin-1;
tempIm = sort(imageGreyscale(:));
darkExtreme = tempIm(max(1,round(0.01*length(tempIm))));
brightExtreme = tempIm(round(0.99*length(tempIm)));
contrast = max(paper-darkExtreme,brightExtreme-paper);
if((brightExtreme-paper) > (paper-darkExtreme))
    imageGreyscale = min(255,max(0,2*paper-imageGreyscale));
end
maskThreshold = max(5,0.1*contrast);
mask = abs(imageGreyscale-paper) > maskThreshold;
if(~any(mask(:)) || ~any(~mask(:)))
    error('Unable to separate the printed feature from the paper');
end
paper = mean(imageGreyscale(~mask));
end

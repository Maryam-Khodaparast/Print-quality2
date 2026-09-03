function [imageOut,info] = pqLegacyFindChannel2Use(imageIn)
% pqLegacyFindChannel2Use The original standard deviation based selection
%
%   Kept as the baseline for tests/pqCompareChannelSelection. The neutral
%   image is built with min(imageIn,[],3) here, the way the original meant
%   to, so that comparisons are about the selection metric and not about
%   that bug.
numberSeps = size(imageIn,3);
stdDevSep = zeros(1,numberSeps);
for sep = 1:numberSeps
    thisSep = imageIn(:,:,sep);
    stdDevSep(sep) = std(double(thisSep(:)));
end
imNeutral = min(imageIn,[],3);
stdDevNeutral = std(double(imNeutral(:)));
if(stdDevNeutral > max(stdDevSep))
    imageOut = imNeutral;
    info.method = 'neutral (min of channels)';
    info.sep2Use = NaN;
    info.weights = [];
else
    sep2Use = find(stdDevSep == max(stdDevSep),1,'first');
    imageOut = imageIn(:,:,sep2Use);
    info.method = sprintf('channel %d',sep2Use);
    info.sep2Use = sep2Use;
    info.weights = double((1:numberSeps) == sep2Use);
end
info.standardDeviations = [stdDevSep stdDevNeutral];
end

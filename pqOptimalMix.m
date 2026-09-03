function [mixImage,weights] = pqOptimalMix(scan,inkMask,paperMask)
% pqOptimalMix Noise whitened combination of the channels of a scan
%
%   [mixImage,weights] = pqOptimalMix(scan,inkMask,paperMask) returns the
%   weighted sum of channels that maximises the contrast to noise ratio of
%   ink against paper, or [] when the scan does not support one.
%
%   Ink usually shows up in more than one channel and scanner noise is
%   correlated between channels, so the best combination is neither the mean
%   nor any single channel. With the paper and ink levels of each channel in
%   paperLevels and inkLevels, and the noise covariance between channels in
%   C, the weights that maximise CNR are C\(paperLevels-inkLevels): the
%   matched filter for ink, which both adds the channels that carry signal
%   and subtracts the noise they share. C is measured over the paper, the
%   one part of the scan with no print in it.
%
%   The weights are scaled to sum to one, so the result stays on the code
%   value scale of the scan and the paper keeps its level. A mix that would
%   not hold that scale is rejected rather than returned.
mixImage = [];
weights = [];
minimumPositiveSum = 0.2;

numberSeps = size(scan,3);
if(numberSeps < 2 || sum(inkMask(:)) < 50 || sum(paperMask(:)) < 500)
    return
end

pixels = reshape(double(scan),[],numberSeps);
inkLevels = mean(pixels(inkMask(:),:),1)';
paperLevels = mean(pixels(paperMask(:),:),1)';
noiseCovariance = cov(pixels(paperMask(:),:));
% Regularise: keep the inverse well behaved, and never claim to know the
% noise better than the quantisation of the data allows (variance 1/12).
noiseCovariance = noiseCovariance ...
    +(1/12+1e-3*trace(noiseCovariance)/numberSeps)*eye(numberSeps);
if(rcond(noiseCovariance) < 1e-10)
    return
end

separation = paperLevels-inkLevels;
if(sum(separation) < 0)
    % A feature lighter than paper; mix it so that paper still keeps its
    % level and the feature stays the lighter of the two
    separation = -separation;
end
weights = noiseCovariance\separation;
% Only accept a mix that still behaves like a scan, which needs the weights
% to sum to a healthy positive number
if(~all(isfinite(weights)) || sum(weights) < minimumPositiveSum*max(abs(weights)))
    weights = [];
    return
end
weights = (weights/sum(weights))';
mixImage = reshape(pixels*weights',size(scan,1),size(scan,2));
end

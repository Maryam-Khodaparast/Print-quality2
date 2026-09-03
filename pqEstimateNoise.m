function sigma = pqEstimateNoise(plane,paperLevel)
% pqEstimateNoise Noise standard deviation of an image, robust to content
%
%   sigma = pqEstimateNoise(plane) estimates the pixel noise of plane
%   without needing a flat patch to measure it on.
%
%   sigma = pqEstimateNoise(plane,paperLevel) also measures the noise over
%   the paper alone, which is the one part of a scan guaranteed to have no
%   print in it, and takes that if it is the lower of the two.
%
%   Two estimators are used and the smaller taken, because image content can
%   only ever push an estimate up:
%     * the response to the 3x3 Laplacian of Immerkaer, which is blind to
%       constant, linear and quadratic shading, so an illumination gradient
%       across the scan does not register as noise
%     * the spread of neighbouring pixel differences
%   Both are medians of absolute values scaled to a standard deviation, so
%   edges, text and halftone dots - always a minority of the pixels of a
%   scan - do not inflate them the way a standard deviation would. A large
%   scan is measured over a grid of tiles taken from across it, see pqMosaic.
plane = pqMosaic(double(plane));

% The mask has a sum of squares of 36, so the response to pure noise has a
% standard deviation of 6 sigma. The difference of two independent pixels
% has a standard deviation of sqrt(2) sigma.
laplacian = [1 -2 1; -2 4 -2; 1 -2 1];
response = abs(conv2(plane,laplacian,'valid'));
horizontal = abs(diff(plane,1,2));
vertical = abs(diff(plane,1,1));
sigma = pqSmallerEstimate(response,horizontal,vertical);

if(nargin > 1 && ~isempty(paperLevel) && isfinite(sigma))
    onPaper = abs(plane-paperLevel) < max(3*sigma,1);
    if(sum(onPaper(:)) > 0.02*numel(plane))
        sigma = min(sigma,pqSmallerEstimate( ...
            response(onPaper(2:end-1,2:end-1)), ...
            horizontal(onPaper(:,1:end-1) & onPaper(:,2:end)), ...
            vertical(onPaper(1:end-1,:) & onPaper(2:end,:))));
    end
end
if(~isfinite(sigma))
    sigma = 0;
end
end

function sigma = pqSmallerEstimate(response,horizontal,vertical)
if(isempty(response))
    sigmaLaplacian = Inf;
else
    sigmaLaplacian = 1.4826*median(pqSample(response))/6;
end
differences = [horizontal(:); vertical(:)];
if(isempty(differences))
    sigmaDifference = Inf;
else
    sigmaDifference = 1.4826*median(pqSample(differences))/sqrt(2);
end
sigma = min(sigmaLaplacian,sigmaDifference);
end

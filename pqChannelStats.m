function [stats,inkMask] = pqChannelStats(plane,sigmaFloor,referenceMask,detectScale)
% pqChannelStats Measure how well one greyscale plane separates ink from paper
%
%   [stats,inkMask] = pqChannelStats(plane,sigmaFloor) finds the printed
%   area of the plane on its own and measures the plane over it.
%
%   [stats,inkMask] = pqChannelStats(plane,sigmaFloor,[],detectScale) looks
%   for the print in a box average of that size rather than in the raw
%   pixels, which finds print too faint to clear the noise pixel by pixel.
%
%   stats = pqChannelStats(plane,sigmaFloor,referenceMask) measures the
%   plane over a printed area that was found somewhere else, so that every
%   channel and every combination of channels is judged over the same
%   pixels. Print is the same physical thing in every channel, so measuring
%   each one over its own idea of where the print is compares them over
%   different pixels, and lets whatever a channel happens to contain - dust,
%   a noise spike, a scratch - be measured as if it were print.
%
%   stats fields:
%       paper       - paper code value (mode of the histogram)
%       sigma       - noise standard deviation, robust to image content
%       contrast    - ink to paper contrast over the printed area
%       cnr         - contrast/sigma, the score selection is made on
%       inkIsDark   - true when the printed feature is darker than paper
%       inkFraction - printed share of the scan
%       hasFeature  - true when this plane shows the print at all
%       contrastExtreme - contrast between the 1% and 99% points
%
%   Contrast is a median over the printed area rather than a percentile of
%   the whole scan, which makes it independent of how much of the scan is
%   printed: a fine line and a solid patch of the same ink measure the same.
if(nargin < 2 || isempty(sigmaFloor))
    sigmaFloor = 0;
end
if(nargin < 3)
    referenceMask = [];
end
if(nargin < 4 || isempty(detectScale))
    detectScale = 1;
end
plane = double(plane);

% Noise floor of this plane, then refined over paper only once the paper
% level is known (the paper is the one area guaranteed to be featureless).
stats.paper = pqPaperLevel(plane);
sigma = max(pqEstimateNoise(plane,stats.paper),sigmaFloor);
stats.sigma = sigma;

if(isempty(referenceMask))
    darkPoint = pqPercentile(plane,1);
    brightPoint = pqPercentile(plane,99);
    stats.contrastExtreme = max(stats.paper-darkPoint,brightPoint-stats.paper);
    % Find the print in this plane: the pixels that stand clear of the
    % paper peak and have company. Noise alone puts about one pixel in two
    % million past five sigma and those are scattered, so a packed
    % population of this size is print, however small a share of the scan.
    if(detectScale > 1)
        % Faint print does not clear the noise pixel by pixel, so it is
        % looked for in a box average, where the noise is smaller by the
        % size of the box
        detectPlane = pqBoxFilter(plane,detectScale);
        detectSigma = sigma/detectScale;
        darkPoint = pqPercentile(detectPlane,1);
        brightPoint = pqPercentile(detectPlane,99);
    else
        detectPlane = plane;
        detectSigma = sigma;
    end
    stats.inkIsDark = (stats.paper-darkPoint) >= (brightPoint-stats.paper);
    inkMask = pqDenseRegions( ...
        pqDeviation(detectPlane,stats.paper,stats.inkIsDark) ...
        > max(5*detectSigma,0.5));
    inkMask = pqPrintedArea(inkMask);
    % Print found by averaging over a box has to be several boxes big:
    % noise averaged over a box still throws the odd box sized blob, and one
    % of those is not print. Print also leaves the paper as the majority of
    % the scan, so anything covering more than that is shading, not print.
    minimumArea = max(20,4*detectScale^2);
    stats.hasFeature = sum(inkMask(:)) >= minimumArea ...
        && mean(inkMask(:)) < 0.6;
    deviation = pqDeviation(plane,stats.paper,stats.inkIsDark);
    if(stats.hasFeature)
        stats.contrast = median(pqSample(deviation(inkMask)));
    else
        stats.contrast = stats.contrastExtreme;
    end
else
    % Measure over the printed area found elsewhere. Only those pixels are
    % touched, which is what keeps this cheap enough to run over every
    % candidate on a full size scan.
    inkMask = referenceMask;
    printed = pqSample(plane(inkMask));
    stats.inkIsDark = mean(printed) <= stats.paper;
    if(stats.inkIsDark)
        stats.contrast = stats.paper-median(printed);
    else
        stats.contrast = median(printed)-stats.paper;
    end
    stats.contrastExtreme = stats.contrast;
    stats.hasFeature = stats.contrast > sigma;
end
stats.inkFraction = sum(inkMask(:))/numel(plane);
stats.cnr = max(stats.contrast,0)/stats.sigma;
end

function printedArea = pqPrintedArea(inkMask)
% Where the print barely clears the noise, the pixels that do clear it are
% the ones the noise happened to favour, and measuring only those reads back
% a contrast that is mostly noise. Those pixels give themselves away by
% standing on their own: a pixel of a line or of a halftone dot has its
% immediate neighbours with it, a pixel the noise lifted over the gate has
% not. When that is what they are, the area they are scattered over is taken
% as the printed area instead of the pixels themselves.
printedArea = inkMask;
if(~any(inkMask(:)))
    return
end
neighbours = conv2(ones(3,1)/3,ones(1,3)/3,double(inkMask),'same');
if(median(neighbours(inkMask)) >= 0.35)
    return
end
boxSize = 11;
density = conv2(double(inkMask),ones(boxSize)/boxSize^2,'same');
grown = density >= 0.03;
if(mean(grown(:)) < 0.6)
    printedArea = grown;
end
end

function deviation = pqDeviation(plane,paper,inkIsDark)
if(inkIsDark)
    deviation = paper-plane;
else
    deviation = plane-paper;
end
end

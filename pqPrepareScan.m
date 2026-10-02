function prepared = pqPrepareScan(scan)
% pqPrepareScan Put a scan into the form the separation analysis needs
%
%   prepared = pqPrepareScan(scan) returns a double plane with the ink dark,
%   the paper code value, the noise and the ink to paper contrast.
%
%   A colour scan goes through selectChannel, which picks the channel or the
%   combination of channels that lifts the ink furthest clear of the noise
%   and refuses the scan if none of them does. A scan that is already one
%   plane is taken as it is, with its polarity decided from which side of
%   paper the extreme values of the scan lie on.

prepared = struct('grey',[],'paper',NaN,'noise',NaN,'contrast',NaN, ...
    'method','');
if(size(scan,3) > 1)
    [grey,mask,paper] = selectChannel(scan);
    prepared.grey = grey;
    prepared.paper = paper;
    prepared.noise = pqEstimateNoise(grey,paper);
    prepared.contrast = paper-median(grey(mask));
    prepared.method = 'selectChannel';
    return
end

grey = double(scan);
paper = pqPaperLevel(grey);
darkest = pqPercentile(grey,1);
brightest = pqPercentile(grey,99);
if(brightest-paper > paper-darkest)
    % The feature is brighter than the paper. Reflecting about the paper
    % value leaves the paper value itself where it is.
    grey = 2*paper-grey;
    prepared.method = 'singlePlane, inverted';
else
    prepared.method = 'singlePlane';
end
prepared.paper = paper;
prepared.noise = pqEstimateNoise(grey,paper);
prepared.contrast = paper-pqPercentile(grey,1);
prepared.grey = grey;
end

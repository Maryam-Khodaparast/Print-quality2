function paper = pqPaperLevel(plane)
% pqPaperLevel Paper code value of a scan, taken as the histogram mode
%
%   The paper is the most common intensity in a scan of a print, so the
%   histogram peak locates it whatever the ink coverage is. A large scan is
%   thinned first, since a peak does not need ten million pixels to place. The peak is
%   lightly smoothed first so that a single spiky code value cannot win it,
%   and the answer is the centroid of the peak so that it is not limited to
%   whole code values.
plane = double(plane);
values = pqSample(plane(isfinite(plane)),5e5);
if(isempty(values))
    paper = NaN;
    return
end
lowest = min(values);
highest = max(values);
if(highest <= lowest)
    paper = lowest;
    return
end
numberBins = 256;
binWidth = (highest-lowest)/numberBins;
bin = min(numberBins,max(1,floor((values-lowest)/binWidth)+1));
counts = accumarray(bin,1,[numberBins 1]);
% A scan whose paper is bright enough to clip piles every clipped pixel onto
% one code value. A spike like that is not the paper level, it is what is
% left of everything above it, so it is dropped before the peak is taken.
% Unless it is most of the scan: paper that has been clipped wholesale is
% still where the paper is, however badly the scan was exposed.
spikeLimit = 0.25*numel(values);
if(counts(1) > 2*counts(2) && counts(1) < spikeLimit)
    counts(1) = 0;
end
if(counts(end) > 2*counts(end-1) && counts(end) < spikeLimit)
    counts(end) = 0;
end
counts = conv(counts,[1;2;3;2;1]/9,'same');
[~,peak] = max(counts);
window = max(1,peak-2):min(numberBins,peak+2);
centres = lowest+(window(:)-0.5)*binWidth;
paper = sum(centres.*counts(window))/sum(counts(window));
end

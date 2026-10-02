function [offset,quality] = pqRegisterPattern(grey,paper,pattern,searchRange)
% pqRegisterPattern Whole pixel position of a printed band within a scan
%
%   offset = pqRegisterPattern(grey,paper,pattern) returns the [row column]
%   shift that brings the nominal pattern onto the scan, so that a band
%   placed anywhere on the sheet can still be read.
%
%   The search is on the row and column sums of the ink rather than on the
%   image, which is two one dimensional correlations instead of a two
%   dimensional one, and is enough because the band is built from rows and
%   columns of features. It only ever has to find the whole pixel part: the
%   fraction of a pixel is the measurement, and it is left alone.
%
%   quality is the peak correlation as a fraction of the correlation of the
%   nominal pattern with itself. A band that is not there, or is upside
%   down, scores near zero, which is how a scan of the wrong chart is caught
%   before any separation is reported.
if(nargin < 4 || isempty(searchRange))
    searchRange = 24;
end
if(isfield(pattern,'profile') && ~isempty(pattern.profile))
    profile = pattern.profile;
else
    profile = pqPatternProfile(pattern);
end
ink = max(0,paper-double(grey));
offset = [0 0];
quality = 0;
if(any(size(ink) < pattern.size))
    return
end
[offset(1),qualityRows] = pqBestShift(sum(ink,2),profile.rows,searchRange);
[offset(2),qualityColumns] = pqBestShift(sum(ink,1)',profile.columns,searchRange);
quality = min(qualityRows,qualityColumns);
end

function [shift,quality] = pqBestShift(measured,reference,searchRange)
% Shift of reference that best matches measured, by correlation, with both
% profiles taken about their own mean so a difference in overall ink level
% does not move the peak.
measured = measured(:)-mean(measured(:));
reference = reference(:)-mean(reference(:));
span = numel(reference);
best = -Inf;
shift = 0;
for candidate = -searchRange:searchRange
    index = (1:span)+candidate;
    inside = index >= 1 & index <= numel(measured);
    if(sum(inside) < 0.5*span)
        continue
    end
    here = measured(index(inside));
    there = reference(inside);
    % Normalised correlation, so the score is a fraction of a perfect match
    % whatever the ink level of the scan is, and a scan of the wrong chart
    % scores near zero rather than merely lower than some other scan.
    score = sum(here.*there)/sqrt(max(sum(here.^2)*sum(there.^2),eps));
    if(score > best)
        best = score;
        shift = candidate;
    end
end
quality = best;
if(~isfinite(quality))
    quality = 0;
end
end

function bitmap = pqPatternBitmap(pattern)
% pqPatternBitmap The one bit bitmap to send to the printer
%
%   bitmap = pqPatternBitmap(pattern) is true where a nozzle fires. All the
%   geometry is on whole pixel boundaries, so the coverage is 0 or 1 and the
%   threshold below never has to decide anything.
%
%   Which head fires each pixel is pattern.rectOwner, and it is not in the
%   bitmap. The chart composer has to route the two sets of pixels to the two
%   heads, which is why pqHeadSeparationChart will not write a production
%   bitmap for a join whose routing has not been confirmed.
coverage = pqRenderPattern(pattern);
bitmap = coverage > 0.5;
if(any(abs(coverage(:)-round(coverage(:))) > 1e-9))
    writeToDebugLog(['Pattern geometry is not on whole pixel boundaries, ' ...
        'the bitmap is a rounded version of it'],'warning')
end
end

function profile = pqPatternProfile(pattern)
% pqPatternProfile Row and column ink profiles of a nominal pattern
%
%   Registration only needs how much ink the pattern has in each row and in
%   each column, so the generators work these out once and keep them. A band
%   is then registered without rasterising a few thousand rectangles again
%   for every scan.
coverage = pqRenderPattern(pattern);
profile = struct('rows',sum(coverage,2),'columns',sum(coverage,1)');
end

function [coverage,byHead] = pqRenderPattern(pattern,owners)
% pqRenderPattern Nominal ink coverage of a pattern, and of each head
%
%   coverage = pqRenderPattern(pattern) is the ink coverage of the whole
%   band, 0 for paper and 1 for solid ink.
%
%   [coverage,byHead] = pqRenderPattern(pattern) also returns a 1 by 2 cell
%   array with the coverage of head A and of head B on their own. Keeping the
%   two separate is the point: the simulator displaces and grows one head
%   without touching the other, and the debug figures can show which head is
%   supposed to have printed any given mark.
%
%   coverage = pqRenderPattern(pattern,owners) renders only the heads listed
%   in owners (1 for head A, 2 for head B).
if(nargin < 2 || isempty(owners))
    owners = [1 2];
end
byHead = {zeros(pattern.size),zeros(pattern.size)};
for owner = owners
    byHead{owner} = pqRasteriseRects( ...
        pattern.rects(pattern.rectOwner == owner,:),pattern.size);
end
coverage = min(1,byHead{1}+byHead{2});
end

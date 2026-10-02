function [width,featureWidths,kinds] = pqWitnessWidth(options)
% pqWitnessWidth How many columns one head's ink witness features need
%
%   [width,featureWidths,kinds] = pqWitnessWidth(options) returns the columns
%   the witness band takes up, and the width and kind of each feature in the
%   order they are laid out: the solid reference patch, then a run of ink
%   line and paper gap pairs for each arm run width.
%
%   The clear space between features is not cosmetic. An ink line is measured
%   over a window wide enough to hold it however far its head has moved, and
%   wide enough again to find the paper either side of it. If the next
%   feature along is inside that window, the paper the line is measured
%   against is somebody else's ink, and the width comes back as nonsense.
%   pqSplitXPattern sizes the band from this rather than the other way round.
options = pqWitnessDefaults(options);
featureWidths = options.patchColumns;
kinds = {'patch'};
for width = options.featureWidth(:)'
    for pair = 1:options.pairs
        featureWidths = [featureWidths width options.blockColumns]; %#ok<AGROW>
        kinds = [kinds {'line'} {'gap'}];                           %#ok<AGROW>
    end
end
width = sum(featureWidths)+(numel(featureWidths)-1)*options.clearColumns;
end

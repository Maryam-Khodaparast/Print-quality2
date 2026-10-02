function [witness,rowsUsed] = pqWitnessBand(topRow,columnFirst,columnLast,options)
% pqWitnessBand The ink growth witness features, for both heads
%
%   [witness,rowsUsed] = pqWitnessBand(topRow,columnFirst,columnLast,options)
%   lays out one band per head: a solid reference patch, then ink lines and
%   paper gaps in equal numbers, alternating.
%
%   The features are the widths of the arm runs, not one comfortable wide
%   bar, because ink growth can depend on the size of the feature it is
%   growing on and the witness has to speak for the arms. There is a run of
%   features for each arm width, so the two can be compared. They are spread
%   across the whole width of the band so that a run of dead adjacent
%   nozzles can reach at most one of them, and the measurement takes the
%   median.
%
%   Why both polarities: ink growing by gLeft and gRight makes a nominally w
%   wide ink line w+gLeft+gRight wide, and a nominally w wide paper gap
%   w-gLeft-gRight wide. Half their difference is the total growth, with the
%   nominal width and any bias of the width measurement itself cancelling
%   out. pqInkGain does that arithmetic and docs/head-separation.md says what
%   it is worth.
options = pqWitnessDefaults(options);
[needed,featureWidths,kinds] = pqWitnessWidth(options);
available = columnLast-columnFirst+1;
if(available < needed)
    error('PrintQuality:pqWitnessBand:tooNarrow', ...
        'A witness band needs at least %d columns, %d were offered', ...
        needed,available);
end
gap = options.clearColumns+floor((available-needed)/(numel(featureWidths)-1));

witness = struct('owner',{},'kind',{},'rows',{},'columns',{}, ...
    'nominalWidth',{},'index',{});
for owner = 1:2
    rows = topRow+(owner-1)*(options.rows+options.clearRows) ...
        +(0:options.rows-1);
    left = columnFirst;
    nominal = max(options.featureWidth);
    for feature = 1:numel(featureWidths)
        columns = left+(0:featureWidths(feature)-1);
        if(strcmp(kinds{feature},'line'))
            nominal = featureWidths(feature);
        elseif(strcmp(kinds{feature},'gap'))
            nominal = nominal;      % a gap is as wide as the line before it
        end
        witness(end+1) = struct('owner',owner,'kind',kinds{feature}, ...
            'rows',rows,'columns',columns, ...
            'nominalWidth',nominal,'index',feature); %#ok<AGROW>
        left = left+featureWidths(feature)+gap;
    end
end
rowsUsed = 2*options.rows+options.clearRows;
end

function pattern = pqMultiMarkPattern(join,options)
% pqMultiMarkPattern Geometry of one MultiMark head separation band
%
%   pattern = pqMultiMarkPattern(join) builds a band of plain rectangular
%   marks that measures the same thing as pqSplitXPattern by a different
%   route, so the two can be compared. It is easier to inspect by eye, it
%   does not depend on fitting diagonals, and its several baselines give it
%   something Split-X has not got.
%
%   Each measurement row holds three head A marks and three head B marks,
%   paired into three A to B baselines of different nominal length, all
%   centred on the same place. If the scanner's x scale is out by a fraction
%   e, a baseline of nominal length d comes back long by e*d, so
%
%       measured(d) - d = displacement + e*d
%
%   and a straight line through the three baselines separates the two: the
%   intercept is the displacement, and it is the value at zero baseline,
%   where a scale error does nothing. The slope is the scale error itself.
%   A single baseline cannot do this at all - it reports displacement plus
%   e*d and has no way of knowing which is which.
%
%   The control row holds a pair of marks from head A at the longest nominal
%   separation and a pair from head B at the middle one. Both pairs are one
%   head, so their true separation is exactly their nominal separation, and
%   what they read is the scanner's scale with no head displacement mixed in.
%   That is an independent check on the slope fitted above.
%
%   The band carries the same ink growth witness as the Split-X band, and
%   what it can and cannot say about ink growth is the same - see pqInkGain
%   and docs/head-separation.md.
if(nargin < 1 || isempty(join))
    join = pqHeadJoins();
    join = join(1);
end
if(nargin < 2)
    options = struct;
end
options = pqMultiMarkDefaults(options);

pattern = struct;
pattern.name = 'multimark-v1';
pattern.joinName = join.joinName;
pattern.headA = join.headA;
pattern.headB = join.headB;
pattern.routingVerified = join.routingVerified;
pattern.micronsPerPixel = options.micronsPerPixel;
pattern.options = options;

baselines = sort(options.baselines(:)');
halfSpan = max(baselines)/2+options.markColumns;
centreColumn = options.marginColumns+halfSpan;
bandWidth = centreColumn+halfSpan+options.marginColumns;

witnessOptions = struct('featureWidth',options.markColumns, ...
    'rows',options.witnessRows,'clearRows',options.witnessClearRows, ...
    'pairs',options.witnessPairs,'patchColumns',options.witnessPatchColumns, ...
    'blockColumns',options.witnessBlockColumns, ...
    'clearColumns',options.witnessClearColumns);
bandWidth = max(bandWidth,pqWitnessWidth(witnessOptions)+2*options.marginColumns);
centreColumn = round(bandWidth/2);

rowPitch = options.markRows+options.clearRows;
top = options.marginRows;
pairs = struct('row',{},'kind',{},'baseline',{},'ownerLeft',{}, ...
    'ownerRight',{},'left',{},'right',{});
for row = 1:options.measurementRows
    rows = top+(row-1)*rowPitch+(0:options.markRows-1);
    for k = 1:numel(baselines)
        pairs(end+1) = pqMakePair(rows,'measure',baselines(k), ...
            1,2,centreColumn,options);                           %#ok<AGROW>
    end
end
rows = top+options.measurementRows*rowPitch+(0:options.markRows-1);
pairs(end+1) = pqMakePair(rows,'controlA',baselines(end),1,1,centreColumn,options);
pairs(end+1) = pqMakePair(rows,'controlB',baselines(max(1,end-1)),2,2,centreColumn,options);
pattern.pairs = pairs;

witnessTop = rows(end)+options.witnessClearRows;
pattern.witness = pqWitnessBand(witnessTop,options.marginColumns, ...
    bandWidth-options.marginColumns,witnessOptions);
bandHeight = witnessTop+2*options.witnessRows+options.witnessClearRows ...
    +options.marginRows;
pattern.size = [bandHeight bandWidth];

[pattern.rects,pattern.rectOwner] = pqMultiMarkRects(pattern);
pattern.profile = pqPatternProfile(pattern);
end

function pair = pqMakePair(rows,kind,baseline,ownerLeft,ownerRight,centreColumn,options)
% One pair of marks, straddling the centre of the band at the nominal
% separation. Putting every pair on the same centre means every baseline
% uses the same part of the scan, so a distortion that varies across the
% sheet affects the long baseline and the short one alike.
half = baseline/2;
pair = struct('row',rows(1),'kind',kind,'baseline',baseline, ...
    'ownerLeft',ownerLeft,'ownerRight',ownerRight, ...
    'left',struct('owner',ownerLeft,'rows',rows, ...
        'columns',round(centreColumn-half)+(0:options.markColumns-1) ...
        -floor(options.markColumns/2)), ...
    'right',struct('owner',ownerRight,'rows',rows, ...
        'columns',round(centreColumn+half)+(0:options.markColumns-1) ...
        -floor(options.markColumns/2)));
end

function [rects,owner] = pqMultiMarkRects(pattern)
rects = zeros(0,4);
owner = zeros(0,1);
for k = 1:numel(pattern.pairs)
    for side = {'left','right'}
        mark = pattern.pairs(k).(side{1});
        rects(end+1,:) = [mark.rows(1)-0.5 mark.rows(end)+0.5 ...
            mark.columns(1)-0.5 mark.columns(end)+0.5];          %#ok<AGROW>
        owner(end+1,1) = mark.owner;                              %#ok<AGROW>
    end
end
for k = 1:numel(pattern.witness)
    feature = pattern.witness(k);
    rows = [feature.rows(1)-0.5 feature.rows(end)+0.5];
    columns = [feature.columns(1)-0.5 feature.columns(end)+0.5];
    if(strcmp(feature.kind,'gap'))
        middle = mean(columns);
        half = feature.nominalWidth/2;
        rects = [rects; rows columns(1) middle-half; ...
            rows middle+half columns(2)];                         %#ok<AGROW>
        owner = [owner; feature.owner; feature.owner];             %#ok<AGROW>
    else
        rects = [rects; rows columns];                             %#ok<AGROW>
        owner = [owner; feature.owner];                            %#ok<AGROW>
    end
end
end

function options = pqMultiMarkDefaults(options)
% baselines        nominal A to B separations, pixels. They have to differ by
%                  a lot for the straight line through them to separate a
%                  displacement from a scale error
% markColumns      width of a mark. The same as the wider Split-X arm run, so
%                  the ink on the two bands grows the same way
defaults = struct( ...
    'micronsPerPixel',25400/720, ...
    'baselines',[64 256 1024], ...
    'markColumns',7, ...
    'markRows',160, ...
    'measurementRows',2, ...
    'clearRows',24, ...
    'marginRows',24, ...
    'marginColumns',40, ...
    'witnessRows',120, ...
    'witnessClearRows',24, ...
    'witnessPairs',3, ...
    'witnessPatchColumns',40, ...
    'witnessBlockColumns',56, ...
    'witnessClearColumns',36);
names = fieldnames(defaults);
for k = 1:numel(names)
    if(~isfield(options,names{k}) || isempty(options.(names{k})))
        options.(names{k}) = defaults.(names{k});
    end
end
end

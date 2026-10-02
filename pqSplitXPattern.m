function pattern = pqSplitXPattern(join,options)
% pqSplitXPattern Geometry of one Split-X head separation band
%
%   pattern = pqSplitXPattern(join) builds the nominal geometry of a band
%   that measures the cross web displacement of join.headB relative to
%   join.headA. pqRenderPattern turns it into a bitmap, pqAnalyseSplitX
%   reads it back off a scan.
%
%   The mark it is built from is an X with a hole in the middle: two diagonal
%   arms at 45 degrees crossing at a virtual centre, printed on both sides of
%   that centre and not at it. Fitting a line to each arm and crossing the two
%   lines gives the centre to a small fraction of a pixel.
%
%   The hole matters, and so does its being in the middle. The centre is then
%   surrounded by the rows the lines were fitted to rather than beyond their
%   end, so it is interpolated and not extrapolated. A line fitted to n rows
%   locates a point at the middle of them to scatter/sqrt(n), and a point a
%   lever arm away to several times that - with arms that stop short of the
%   centre, as the first versions of this pattern had them, four times worse
%   here, and that extrapolation was the largest single error in the
%   measurement. The hole is sized so that the two arms are further apart
%   where they are closest than the windows they are measured in are wide.
%
%   Each measurement group is three such marks in a column, printed
%   A B A - the head under test in the middle, the reference head above and
%   below it - and the separation is
%
%       separation = (centre x of B - mean centre x of the two A marks)
%                    * micronsPerPixel
%
%   with no nominal distance to subtract and nothing to unwrap. A negative
%   result means head B sits to the left of head A and stays negative.
%
%   Taking the mean of the two outer marks puts the reference at the same
%   height down the band as the mark between them, so anything that slides
%   the scan sideways in proportion to how far down it is - a sheet fed in
%   skew, a tilted scanner - moves the reference and the mark under test
%   alike and cancels. Groups alternate A B A and B A B so that over the band
%   each head prints the same marks in the same places.
%
%   Three things in the geometry are there for the analysis rather than for
%   the picture:
%
%   * Every mark is congruent with every other: equal slopes, arm lengths,
%     run widths and column spans, in the same columns. Blur, symmetric dot
%     gain and any growth common to both heads then move every centre the
%     same way and cancel in the difference.
%   * Same head control groups to the left and the right print all three
%     marks from one head, so their true separation is zero and whatever they
%     read is scanner, web or lens distortion rather than head displacement.
%   * The ink witness band (see pqInkGain) carries, per head, a solid
%     reference patch and equal numbers of 3 pixel ink lines and 3 pixel
%     paper gaps, the same width as the arm runs. Those measure how far each
%     head's ink has grown past its nominal edges. Asymmetric growth moves
%     the ink of a head bodily sideways, which is indistinguishable from
%     moving the head, so the witness cannot correct the separation - it is
%     what lets the analyser say the number is not trustworthy instead of
%     reporting it as good. docs/head-separation.md gives the argument.
%
%   options (all optional) are documented in pqSplitXDefaults below.
if(nargin < 1 || isempty(join))
    join = pqHeadJoins();
    join = join(1);
end
if(nargin < 2)
    options = struct;
end
options = pqSplitXDefaults(options);

pattern = struct;
pattern.name = 'splitx-v3';
pattern.joinName = join.joinName;
pattern.headA = join.headA;
pattern.headB = join.headB;
pattern.routingVerified = join.routingVerified;
pattern.micronsPerPixel = options.micronsPerPixel;
pattern.options = options;

% ---- column layout: control A, measurement, control B -------------------
markHalfHeight = options.halfGap+floor(options.armColumns/2)-1;
blockHalfWidth = markHalfHeight+ceil(max(options.armRunWidth)/2);
blockPitch = 2*blockHalfWidth+options.blockClearColumns;
blockCentres = options.marginColumns+blockHalfWidth+(0:2)*blockPitch;
bandWidth = blockCentres(end)+blockHalfWidth+options.marginColumns;
blockKinds = {'controlA','measure','controlB'};

% ---- row layout: groups of three marks, then the two witness bands ------
markHeight = 2*markHalfHeight+1;
markPitch = markHeight+options.markClearRows;
groupHeight = 3*markHeight+2*options.markClearRows;
groupPitch = groupHeight+options.groupClearRows;
groupTops = options.marginRows+(0:options.groupCount-1)*groupPitch;
witnessTop = groupTops(end)+groupHeight+options.witnessClearRows;
bandHeight = witnessTop+2*options.witnessRows+options.witnessClearRows ...
    +options.marginRows;
% The witness band may want more width than the measurement blocks do, and
% it is not allowed to be squeezed: see pqWitnessWidth.
witnessOptions = struct('featureWidth',options.armRunWidth, ...
    'rows',options.witnessRows,'clearRows',options.witnessClearRows, ...
    'pairs',options.witnessPairs,'patchColumns',options.witnessPatchColumns, ...
    'blockColumns',options.witnessBlockColumns, ...
    'clearColumns',options.witnessClearColumns);
bandWidth = max(bandWidth, ...
    pqWitnessWidth(witnessOptions)+2*options.marginColumns);
pattern.size = [bandHeight bandWidth];

% ---- marks and their arms ----------------------------------------------
% owner 1 is head A, owner 2 is head B. Every arm records the image rows it
% occupies and its nominal centre column in each of them, so the analyser
% never has to redo this geometry. The rows come in two runs, one each side
% of the mark's own centre, with the hole between them.
arms = struct('owner',{},'group',{},'block',{},'mark',{},'slope',{}, ...
    'rows',{},'centres',{},'runWidth',{});
marks = struct('owner',{},'group',{},'block',{},'apexRow',{}, ...
    'apexColumn',{},'arms',{});
measurements = struct('kind',{},'group',{},'block',{},'runWidth',{}, ...
    'outer',{},'middle',{},'ownerOuter',{},'ownerMiddle',{},'sign',{});
half = floor(options.armColumns/2);
for block = 1:numel(blockCentres)
    kind = blockKinds{block};
    for group = 1:options.groupCount
        % Groups take the two arm run widths in the order narrow, wide, wide,
        % narrow, so that the two sets of groups sit at the same average
        % height in the band. Anything that varies down the band - a tilted
        % head, a bowed web - then affects both sets equally and cancels out
        % of their difference, leaving the difference to mean what it is
        % meant to mean.
        runWidth = options.armRunWidth(1 ...
            +mod(floor((group-1)/2)+mod(group-1,2),numel(options.armRunWidth)));
        % A B A, then B A B, so that over the band each head prints as many
        % outer marks as middle ones.
        if(mod(group,2) == 1)
            owners = [1 2 1];
        else
            owners = [2 1 2];
        end
        switch(kind)
            case 'controlA'
                owners(:) = 1;
            case 'controlB'
                owners(:) = 2;
        end
        markIndices = zeros(1,3);
        for position = 1:3
            apexRow = groupTops(group)+(position-1)*markPitch+markHalfHeight;
            apexColumn = blockCentres(block);
            armIndices = zeros(1,2);
            for slopeIndex = 1:2
                slope = 2*slopeIndex-3;         % -1 then +1
                rows = [apexRow-options.halfGap-half+1:apexRow-options.halfGap ...
                    apexRow+options.halfGap:apexRow+options.halfGap+half-1];
                arms(end+1) = struct('owner',owners(position),'group',group, ...
                    'block',block,'mark',numel(marks)+1,'slope',slope, ...
                    'rows',rows,'centres',apexColumn+slope*(rows-apexRow), ...
                    'runWidth',runWidth);                        %#ok<AGROW>
                armIndices(slopeIndex) = numel(arms);
            end
            marks(end+1) = struct('owner',owners(position),'group',group, ...
                'block',block,'apexRow',apexRow,'apexColumn',apexColumn, ...
                'arms',armIndices);                               %#ok<AGROW>
            markIndices(position) = numel(marks);
        end
        % The separation is always head B minus head A, so a B A B group,
        % which measures A against B, is turned round here rather than
        % anywhere later.
        if(owners(2) == 2)
            sign = 1;
        else
            sign = -1;
        end
        measurements(end+1) = struct('kind',kind,'group',group, ...
            'block',block,'runWidth',runWidth, ...
            'outer',markIndices([1 3]),'middle',markIndices(2), ...
            'ownerOuter',owners(1),'ownerMiddle',owners(2), ...
            'sign',sign);                                         %#ok<AGROW>
    end
end
pattern.arms = arms;
pattern.marks = marks;
pattern.measurements = measurements;

% ---- ink witness -------------------------------------------------------
witness = pqWitnessBand(witnessTop,options.marginColumns, ...
    bandWidth-options.marginColumns,witnessOptions);
pattern.witness = witness;

% ---- rectangles, with the head that owns each one ----------------------
[pattern.rects,pattern.rectOwner] = pqSplitXRects(pattern);
pattern.profile = pqPatternProfile(pattern);
end

function [rects,owner] = pqSplitXRects(pattern)
% Every feature of the band as axis aligned rectangles, one row tall for the
% arms. Edges are continuous: the pixel whose index is c covers x from
% c-0.5 to c+0.5. The simulator grows, shifts, shears and scales these edges
% directly, so it never has to resample a bitmap.
rects = zeros(0,4);
owner = zeros(0,1);
for k = 1:numel(pattern.arms)
    arm = pattern.arms(k);
    half = arm.runWidth/2;
    block = [arm.rows(:)-0.5 arm.rows(:)+0.5 ...
        arm.centres(:)-half arm.centres(:)+half];
    rects = [rects; block];                                     %#ok<AGROW>
    owner = [owner; repmat(arm.owner,size(block,1),1)];          %#ok<AGROW>
end
for k = 1:numel(pattern.witness)
    feature = pattern.witness(k);
    rows = [feature.rows(1)-0.5 feature.rows(end)+0.5];
    columns = [feature.columns(1)-0.5 feature.columns(end)+0.5];
    switch(feature.kind)
        case 'gap'
            % A paper gap of the arm run width, centred in a solid block, so
            % the two edges of the measured feature face the opposite way to
            % the two edges of an ink line. Growth widens the line and
            % narrows the gap by the same amount.
            middle = mean(columns);
            half = feature.nominalWidth/2;
            rects = [rects; rows columns(1) middle-half; ...
                rows middle+half columns(2)];                    %#ok<AGROW>
            owner = [owner; feature.owner; feature.owner];        %#ok<AGROW>
        otherwise
            rects = [rects; rows columns];                        %#ok<AGROW>
            owner = [owner; feature.owner];                       %#ok<AGROW>
    end
end
end

function options = pqSplitXDefaults(options)
% micronsPerPixel  one 720 dpi pixel, 25400/720
% armColumns       nozzle columns each arm uses, and rows it spans at 45 deg
% armRunWidth      horizontal width of an arm in each row, pixels. Two of
%                  them, used by alternate groups, so that the band can show
%                  whether the ink lands in the same place on a narrow
%                  feature as on a wide one
% halfGap          blank rows each side of a mark's centre, the hole in the
%                  middle of the X. It is what keeps the two arms of a mark
%                  far enough apart where they are closest for their
%                  measuring windows not to overlap, and nothing is
%                  extrapolated across it - the centre is interpolated from
%                  rows on both sides
% groupCount       independent measurement groups per band
% witnessPairs     ink lines, and paper gaps, per head, of each arm width
defaults = struct( ...
    'micronsPerPixel',25400/720, ...
    'armColumns',64, ...
    'armRunWidth',[3 7], ...
    'halfGap',18, ...
    'groupCount',4, ...
    'groupClearRows',24, ...
    'markClearRows',16, ...
    'blockClearColumns',17, ...
    'marginRows',24, ...
    'marginColumns',24, ...
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

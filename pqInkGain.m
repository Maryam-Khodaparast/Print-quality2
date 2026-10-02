function gain = pqInkGain(grey,pattern,offset,options)
% pqInkGain How far each head's ink has grown past the edges it aimed at
%
%   gain = pqInkGain(grey,pattern,offset) measures, for head A and head B
%   separately, the solid ink amplitude and the ink growth, from the witness
%   band: features the same widths as the arm runs, half of them ink lines on
%   paper and half of them paper gaps in ink.
%
%   Growth is measured from the two polarities together. If the ink spreads
%   by gLeft past every left hand edge and gRight past every right hand one,
%   then a nominal w wide ink line comes back w+gLeft+gRight wide and a
%   nominal w wide paper gap comes back w-gLeft-gRight wide, so
%
%       growth = (lineWidth-gapWidth)/2 = gLeft+gRight
%
%   without needing to know w, and with any bias in the width measurement
%   itself - the blur, the background level, the integration window -
%   entering the two polarities the same way and cancelling.
%
%   What this is for, and what it is not for, is in docs/head-separation.md.
%   The short version: growing ink by gLeft and gRight is the same thing as
%   moving it sideways by (gRight-gLeft)/2 and growing it evenly by
%   (gLeft+gRight)/2. The even part leaves every centre where it was. The
%   sideways part moves all of that head's ink, which is what a displaced
%   head does, so no measurement of a printed image can tell the two apart.
%   This measurement does not try to. What it gives is
%
%   * growth, per head. A head laying more ink than its neighbour could be
%     doing it evenly, which costs nothing, or all to one side, which costs
%     half the difference. The difference between the heads bounds it.
%   * growth per feature width. Ink that grows by the same amount on a
%     narrow feature and a wide one shifts every feature equally, and a shift
%     of all of a head's ink is a real misplacement of the print whatever
%     caused it. Ink whose growth depends on the feature shifts this band's
%     features by something other than it shifts a printed image, and that is
%     when the band's answer stops being worth having.
%
%   gain(owner).growthByWidth and gain(owner).featureWidths carry the second
%   of those; pqAnalyseSplitX also gets it from the arms themselves, which
%   come in two widths for the same reason.
if(nargin < 3 || isempty(offset))
    offset = [0 0];
end
if(nargin < 4)
    options = struct;
end
defaults = struct('halfWindow',15,'flankPixels',3,'insetRows',3, ...
    'patchInsetColumns',8,'measureMargin',4);
names = fieldnames(defaults);
for k = 1:numel(names)
    if(~isfield(options,names{k}) || isempty(options.(names{k})))
        options.(names{k}) = defaults.(names{k});
    end
end

grey = double(grey);
blank = struct('amplitude',NaN,'lineWidth',NaN,'gapWidth',NaN, ...
    'growth',NaN,'skew',NaN,'spread',NaN,'count',0, ...
    'featureWidths',[],'growthByWidth',[],'widthDependence',NaN);
gain = [blank blank];
for owner = 1:2
    features = pattern.witness([pattern.witness.owner] == owner);
    amplitude = pqPatchAmplitude(grey,features,offset,options);
    gain(owner).amplitude = amplitude;
    if(~isfinite(amplitude) || amplitude <= 0)
        continue
    end
    widths = unique([features(~strcmp({features.kind},'patch')).nominalWidth]);
    gain(owner).featureWidths = widths;
    growthByWidth = nan(size(widths));
    lineWidths = []; gapWidths = []; lineSkews = []; gapSkews = [];
    spreads = [];
    for k = 1:numel(widths)
        chosen = features([features.nominalWidth] == widths(k));
        [line,lineSkew] = pqFeatureWidths(grey,chosen,'line',amplitude,offset,options);
        [gap,gapSkew] = pqFeatureWidths(grey,chosen,'gap',amplitude,offset,options);
        % A nozzle that fails takes ink away and never adds any, so damage
        % makes an ink line narrower and a paper gap wider, and both of those
        % make the growth look smaller than it is. The widest line and the
        % narrowest gap are therefore the least damaged pair there is, and
        % the growth they give is the one to take. Anything that adds ink
        % where it should not be - a deflected nozzle, a speck of dirt -
        % would fool this, which is what the spread below is for.
        growthByWidth(k) = (pqLargest(line)-pqSmallest(gap))/2;
        % Features agree with each other only within one nominal width and
        % one polarity. Measuring the spread over a mixture of widths would
        % be measuring the pattern, not the print.
        spreads = [spreads pqRobustSpread(line) pqRobustSpread(gap)]; %#ok<AGROW>
        lineWidths = [lineWidths line];      %#ok<AGROW>
        gapWidths = [gapWidths gap];          %#ok<AGROW>
        lineSkews = [lineSkews lineSkew];     %#ok<AGROW>
        gapSkews = [gapSkews gapSkew];        %#ok<AGROW>
    end
    gain(owner).growthByWidth = growthByWidth;
    gain(owner).growth = pqMiddle(growthByWidth);
    if(numel(growthByWidth) > 1)
        gain(owner).widthDependence = growthByWidth(end)-growthByWidth(1);
    end
    gain(owner).lineWidth = pqMiddle(lineWidths);
    gain(owner).gapWidth = pqMiddle(gapWidths);
    % An ink line that has spread to the right and a paper gap that the ink
    % has eaten into from the left lean opposite ways, so differencing the
    % two skews adds the signal and removes anything that leans both
    % profiles the same way, such as a tilted scan.
    gain(owner).skew = (pqMiddle(lineSkews)-pqMiddle(gapSkews))/2;
    gain(owner).spread = max(spreads(isfinite(spreads)));
    if(isempty(gain(owner).spread))
        gain(owner).spread = NaN;
    end
    gain(owner).count = sum(isfinite(lineWidths))+sum(isfinite(gapWidths));
end
end

function amplitude = pqPatchAmplitude(grey,features,offset,options)
% Solid ink amplitude of this head, from its reference patch. The median over
% the inside of the patch ignores a dead nozzle, which leaves a light stripe
% over a small part of it, and the inset is wide enough that a head a long
% way out of position still has ink over all of what is sampled.
patch = features(strcmp({features.kind},'patch'));
amplitude = NaN;
if(isempty(patch))
    return
end
patch = patch(1);
rows = patch.rows+offset(1);
columns = patch.columns+offset(2);
inset = options.insetRows;
rows = rows(1+inset:end-inset);
columns = columns(1+options.patchInsetColumns:end-options.patchInsetColumns);
paper = pqPaperBeside(grey,patch.rows+offset(1),patch.columns+offset(2),options);
rows = rows(rows >= 1 & rows <= size(grey,1));
columns = columns(columns >= 1 & columns <= size(grey,2));
if(~isfinite(paper) || isempty(rows) || isempty(columns))
    return
end
amplitude = paper-median(median(grey(rows,columns)));
end

function [widths,skews] = pqFeatureWidths(grey,features,kind,amplitude,offset,options)
% Width of each witness feature of one kind, as the area it stands above its
% own local background divided by the solid ink amplitude, and the
% lopsidedness of its profile.
%
% Two passes, as for an arm: the first finds the feature over the whole
% window, so a head that has moved is still measured on its own ink rather
% than on where the ink should have been, and the second measures it.
chosen = features(strcmp({features.kind},kind));
widths = nan(1,numel(chosen));
skews = nan(1,numel(chosen));
polarity = 1;
if(strcmp(kind,'gap'))
    polarity = -1;      % a light feature on a dark background
end
for k = 1:numel(chosen)
    feature = chosen(k);
    rows = feature.rows+offset(1);
    rows = rows(1+options.insetRows:end-options.insetRows);
    middle = round(mean(feature.columns+offset(2)));
    measureHalfWidth = [options.halfWindow-options.flankPixels ...
        ceil(feature.nominalWidth/2)+options.measureMargin];
    for pass = 1:2
        window = middle-options.halfWindow:middle+options.halfWindow;
        if(rows(1) < 1 || rows(end) > size(grey,1) ...
                || window(1) < 1 || window(end) > size(grey,2))
            break
        end
        strip = mean(grey(rows,window),1);
        [profile,inside] = pqLocalProfile(strip,window,options.flankPixels, ...
            measureHalfWidth(pass),polarity);
        total = sum(profile);
        if(~isfinite(total) || total <= 0)
            break
        end
        centre = sum(inside.*profile)/total;
        if(pass == 1)
            middle = round(centre);
            continue
        end
        widths(k) = total/amplitude;
        third = sum(profile.*(inside-centre).^3)/total;
        skews(k) = sign(third)*abs(third)^(1/3);
    end
end
end

function paper = pqPaperAround(grey,rows,columns,options)
% Paper level just outside a feature, from both sides, so a shading gradient
% across the band cancels rather than biasing the feature.
left = columns(1)-options.flankPixels-options.insetRows:columns(1)-options.insetRows-1;
right = columns(end)+options.insetRows+1:columns(end)+options.insetRows+options.flankPixels;
sides = [left right];
sides = sides(sides >= 1 & sides <= size(grey,2));
rows = rows(rows >= 1 & rows <= size(grey,1));
if(isempty(sides) || isempty(rows))
    paper = NaN;
    return
end
paper = median(median(grey(rows,sides)));
end

function paper = pqPaperBeside(grey,rows,columns,options)
% Paper level beside a wide feature, taking the lighter of the two sides. A
% head far enough out of position puts its ink over the paper on one side of
% where the feature should have been, and the side it has not reached is
% still paper. Averaging the two sides would quietly mix ink into the paper
% level and shrink the ink amplitude with it.
left = pqSideLevel(grey,rows,columns(1)-options.flankPixels-options.insetRows, ...
    columns(1)-options.insetRows-1);
right = pqSideLevel(grey,rows,columns(end)+options.insetRows+1, ...
    columns(end)+options.insetRows+options.flankPixels);
paper = max([left right]);
if(isempty(paper))
    paper = NaN;
end
end

function level = pqSideLevel(grey,rows,first,last)
columns = first:last;
columns = columns(columns >= 1 & columns <= size(grey,2));
rows = rows(rows >= 1 & rows <= size(grey,1));
if(isempty(columns) || isempty(rows))
    level = [];
    return
end
level = median(median(grey(rows,columns)));
end

function value = pqLargest(values)
values = values(isfinite(values));
if(isempty(values))
    value = NaN;
else
    value = max(values);
end
end

function value = pqSmallest(values)
values = values(isfinite(values));
if(isempty(values))
    value = NaN;
else
    value = min(values);
end
end

function middle = pqMiddle(values)
values = values(isfinite(values));
if(isempty(values))
    middle = NaN;
else
    middle = median(values);
end
end

function spread = pqRobustSpread(values)
values = values(isfinite(values));
if(numel(values) < 2)
    spread = NaN;
    return
end
spread = 1.4826*median(abs(values-median(values)));
end

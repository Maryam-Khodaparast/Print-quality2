function [scan,truth] = pqSimulateHeadSeparation(pattern,condition)
% pqSimulateHeadSeparation A synthetic scan of a head separation band
%
%   [scan,truth] = pqSimulateHeadSeparation(pattern,condition) prints the
%   pattern with the faults described by condition, scans it, and returns an
%   8 bit image. truth records what was injected and is for scoring only -
%   it is never passed to the analyser.
%
%   The two heads are rendered separately so that a displacement, a rotation
%   or a dot growth can be applied to one of them alone, and the ink is
%   blurred and then integrated over each pixel from the continuous rectangle
%   edges rather than resampled from a bitmap, so a shift of a hundredth of a
%   pixel really is a shift of a hundredth of a pixel. pqRasteriseRects says
%   why the blur has to come before the pixel and not after it.
%
%   condition fields, all optional:
%     displacementMicrons   head B, cross web, signed
%     displacementYMicrons  head B, down web, signed
%     growthA, growthB      [left right] ink growth past the nominal edge,
%                           pixels, across the web. [0.4 0.4] is ordinary
%                           symmetric dot gain, [0 0.75] is the one sided
%                           growth that no pattern in this family can tell
%                           from a head displacement
%     growthBWidthSlope     extra right hand growth on head B per pixel of
%                           feature width, so the ink lands in a different
%                           place on a narrow feature than on a wide one
%     deadNozzlesA/B        pattern columns that print nothing
%     missingHeadB          head B prints nothing at all
%     headBRotation         radians, about the centre of head B's own ink
%     scannerRotation       radians, applied to the whole scan
%     scannerScaleError     fractional error in the scanner's x scale
%     webDistortion         peak of a quadratic cross web error, pixels
%     blurSigma             optical blur of the scan, pixels
%     samplePhase           [y x] subpixel position of the scan grid
%     paperLevel, contrast, readNoise, paperVariation, seed
condition = pqSimulationDefaults(condition);
pqSeedRandom(condition.seed);
truth = condition;
truth.displacementPixels = condition.displacementMicrons/pattern.micronsPerPixel;

imageSize = pattern.size;
rowReference = imageSize(1)/2;
columnReference = imageSize(2)/2;
inkByHead = {zeros(imageSize),zeros(imageSize)};
for owner = 1:2
    if(owner == 2 && condition.missingHeadB)
        continue
    end
    rects = pattern.rects(pattern.rectOwner == owner,:);
    if(owner == 1)
        growth = condition.growthA;
        dead = condition.deadNozzlesA;
        displacement = [0 0];
        rotation = 0;
    else
        growth = condition.growthB;
        dead = condition.deadNozzlesB;
        displacement = [condition.displacementYMicrons ...
            condition.displacementMicrons]/pattern.micronsPerPixel;
        rotation = condition.headBRotation;
    end

    % Dead nozzles remove the ink before it is grown or moved, because a
    % nozzle that does not fire leaves a gap that the neighbouring ink then
    % grows into.
    rects = pqRemoveColumns(rects,dead);

    % Growth that depends on how wide the feature is. This is the condition
    % the two arm widths are there to find: ink that grows by the same amount
    % on everything shifts a head's whole print and is a real misplacement,
    % and ink that grows differently on different features shifts this chart
    % by something other than it shifts a printed image.
    if(owner == 2 && condition.growthBWidthSlope ~= 0)
        % Saturating, because ink spreading off the edge of a feature stops
        % caring how wide the feature is once it is a few pixels across.
        featureWidth = min(rects(:,4)-rects(:,3),8);
        extra = condition.growthBWidthSlope*max(0,featureWidth-3);
    else
        extra = zeros(size(rects,1),1);
    end

    % Ink growth past the nominal edge, across the web only. Down web growth
    % does not move a cross web centre, and leaving it out keeps the arms as
    % rectangles one row tall that never overlap each other, so the coverage
    % of a head is the exact sum of its rectangles and a shift of a
    % hundredth of a pixel moves the ink by exactly that.
    rects(:,3) = rects(:,3)-growth(1);
    rects(:,4) = rects(:,4)+growth(2)+extra;

    % Head rotation, about the middle of this head's own ink, then the
    % head's displacement.
    if(rotation ~= 0)
        middle = mean(rects(:,1:2),2);
        rects(:,3:4) = rects(:,3:4)+rotation*(middle-mean(middle));
    end
    rects(:,1:2) = rects(:,1:2)+displacement(1);
    rects(:,3:4) = rects(:,3:4)+displacement(2);

    % The scanner and the web see both heads the same way.
    rects(:,3:4) = columnReference ...
        +(1+condition.scannerScaleError)*(rects(:,3:4)-columnReference);
    middle = mean(rects(:,1:2),2);
    rects(:,3:4) = rects(:,3:4)+condition.scannerRotation*(middle-rowReference);
    rects(:,3:4) = rects(:,3:4) ...
        +condition.webDistortion*((middle-rowReference)/rowReference).^2;
    rects(:,1:2) = rects(:,1:2)+condition.samplePhase(1);
    rects(:,3:4) = rects(:,3:4)+condition.samplePhase(2);

    inkByHead{owner} = pqRasteriseRects(rects,imageSize,condition.blurSigma);
end

% Where two heads put ink in the same place the paper does not go twice as
% dark, so the coverage is clipped rather than added. In this pattern the two
% heads never print in the same row of the same block, so the clip is a
% safety net rather than part of the model.
coverage = min(1,inkByHead{1}+inkByHead{2});

plane = condition.paperLevel-condition.contrast*coverage;
if(condition.paperVariation > 0)
    % Slow variation across the sheet, from the paper and the illumination.
    field = pqBoxFilter(randn(imageSize),51);
    field = field/max(1e-9,std(field(:)));
    plane = plane+condition.paperVariation*field;
end
plane = plane+condition.readNoise*randn(imageSize);
plane = max(0,min(255,plane));
if(condition.quantise)
    scan = uint8(round(plane));
else
    % For diagnosis only: a real scanner returns whole code values, and
    % rounding them is a non linearity that depends on where the ink
    % happens to fall on the pixel grid.
    scan = plane;
end

truth.inkByHead = [];   % deliberately not carried: the analyser gets the scan
end

function rects = pqRemoveColumns(rects,columns)
% Cut the pattern columns listed out of every rectangle that crosses them.
% A rectangle split in two comes back as two rectangles, so a dead nozzle in
% the middle of a solid patch leaves a real gap rather than a thin one.
if(isempty(columns))
    return
end
for column = sort(columns(:)')
    dead = [column-0.5 column+0.5];
    keep = zeros(0,4);
    for k = 1:size(rects,1)
        rect = rects(k,:);
        if(rect(4) <= dead(1) || rect(3) >= dead(2))
            keep(end+1,:) = rect;                                %#ok<AGROW>
            continue
        end
        if(rect(3) < dead(1))
            keep(end+1,:) = [rect(1:2) rect(3) dead(1)];         %#ok<AGROW>
        end
        if(rect(4) > dead(2))
            keep(end+1,:) = [rect(1:2) dead(2) rect(4)];         %#ok<AGROW>
        end
    end
    rects = keep;
end
end

function condition = pqSimulationDefaults(condition)
if(nargin < 1 || isempty(condition))
    condition = struct;
end
defaults = struct( ...
    'displacementMicrons',0, ...
    'displacementYMicrons',0, ...
    'growthA',[0.4 0.4], ...
    'growthB',[0.4 0.4], ...
    'deadNozzlesA',[], ...
    'deadNozzlesB',[], ...
    'missingHeadB',false, ...
    'growthBWidthSlope',0, ...
    'headBRotation',0, ...
    'scannerRotation',0, ...
    'scannerScaleError',0, ...
    'webDistortion',0, ...
    'blurSigma',0.8, ...
    'samplePhase',[0 0], ...
    'paperLevel',235, ...
    'contrast',190, ...
    'readNoise',1.5, ...
    'paperVariation',1.0, ...
    'quantise',true, ...
    'seed',1);
names = fieldnames(defaults);
for k = 1:numel(names)
    if(~isfield(condition,names{k}))
        condition.(names{k}) = defaults.(names{k});
    end
end
if(numel(condition.growthA) == 1)
    condition.growthA = condition.growthA*[1 1];
end
if(numel(condition.growthB) == 1)
    condition.growthB = condition.growthB*[1 1];
end
end

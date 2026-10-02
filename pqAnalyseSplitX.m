function result = pqAnalyseSplitX(scan,pattern,options)
% pqAnalyseSplitX Cross web displacement of head B relative to head A
%
%   result = pqAnalyseSplitX(scan,pattern) reads a Split-X band off a scan
%   and returns the signed displacement of head B across the web, in microns,
%   together with an uncertainty and a verdict on whether it can be believed.
%
%   result.separationMicrons    signed, positive when head B sits to the
%                               right of head A. Negative stays negative:
%                               nothing here takes an absolute value, wraps
%                               on the pattern pitch or flips a sign
%   result.uncertaintyMicrons   the random part of the measurement and the
%                               ink growth bound added to it
%   result.valid                true only if every check below passed
%   result.reasons              the checks that did not pass
%   result.groups               what each measurement group read, so a single
%                               bad group can be seen rather than averaged in
%   result.inkBiasBoundMicrons  how far the ink growth measured on the
%                               witness band could have moved the answer
%   result.inkBiasEstimateMicrons
%                               the same size, signed by the direction the
%                               ink was found to have spread. Reported and
%                               never subtracted: see docs/head-separation.md
%
%   The analyser is given the scan and the nominal geometry and nothing else.
%   It is not told the displacement, which nozzles were firing or where the
%   scanner put the sheet.
if(nargin < 3)
    options = struct;
end
options = pqSplitXAnalysisDefaults(options);
micronsPerPixel = pattern.micronsPerPixel;
result = pqEmptyResult(pattern);

prepared = pqPrepareScanSafely(scan);
if(isempty(prepared.grey))
    result.reasons{end+1} = 'scanRefused';
    return
end
result.scan = rmfield(prepared,'grey');
grey = prepared.grey;

[offset,quality] = pqRegisterPattern(grey,prepared.paper,pattern);
result.registration = struct('offset',offset,'quality',quality);
if(quality < options.minimumRegistration)
    result.reasons{end+1} = 'notRegistered';
    return
end

% ---- what each head's ink is doing -------------------------------------
gain = pqInkGain(grey,pattern,offset);
result.inkGain = gain;
amplitude = [gain.amplitude];
if(~all(isfinite(amplitude)) || min(amplitude) < options.minimumAmplitudeRatio*max(amplitude))
    result.reasons{end+1} = 'missingHead';
    return
end

% ---- every arm: centres per row, then a straight line through them ------
arms = pqMeasureArms(grey,pattern,offset,amplitude,prepared.noise,options);
result.arms = arms;

% ---- apexes, and the separation of each group --------------------------
[groups,result.capture] = pqMeasureGroups(pattern,arms,options);
result.groups = groups;

isMeasure = strcmp({groups.kind},'measure');
measureValues = [groups(isMeasure).separationPixels];
controlValues = [groups(~isMeasure).separationPixels];
measureValues = measureValues(isfinite(measureValues));
controlValues = controlValues(isfinite(controlValues));
if(numel(measureValues) < options.minimumGroups)
    result.reasons{end+1} = 'fewGroups';
    return
end

% A control group prints both arm pairs from one head, so whatever it reads
% is the scan's own distortion between the rows of the upper arms and the
% rows of the lower ones, and not a head displacement. Taking it off is a
% correction with a known true value of zero, and it cannot remove an ink
% growth bias because growth moves both arm pairs of a control the same way
% and cancels there.
controlOffset = 0;
if(numel(controlValues) >= options.minimumGroups)
    controlOffset = mean(controlValues);
end
result.controlOffsetMicrons = controlOffset*micronsPerPixel;
result.separationRawMicrons = mean(measureValues)*micronsPerPixel;
result.separationMicrons = result.separationRawMicrons-result.controlOffsetMicrons;

downWeb = [groups(isMeasure).downWebPixels];
result.downWebMicrons = mean(downWeb(isfinite(downWeb)))*micronsPerPixel;

% ---- how much of that could be ink rather than head --------------------
% Growing a head's ink by gLeft and gRight is the same as shifting it by
% (gRight-gLeft)/2 and then growing it evenly. The shift is indistinguishable
% from a head displacement, and it is at most half the total growth.
growthDifference = gain(2).growth-gain(1).growth;
result.growthDifferencePixels = growthDifference;
result.inkBiasBoundMicrons = abs(growthDifference)/2*micronsPerPixel;
skewDifference = gain(2).skew-gain(1).skew;
result.inkBiasEstimateMicrons = sign(skewDifference)*result.inkBiasBoundMicrons;

% The arms are measured in the same way and are made of the same ink, so
% they should agree with the witness about which head has grown and by how
% much. If they do not, the witness is not speaking for the arms.
armGrowth = [pqMiddle([arms([arms.owner] == 1).width]) ...
    pqMiddle([arms([arms.owner] == 2).width])];
result.armGrowthDifferencePixels = armGrowth(2)-armGrowth(1);

% The groups come in two arm widths. Ink that grows by the same amount
% whatever it grows on shifts both widths equally, and both sets of groups
% read the same. They are the test of whether this band's answer is a
% property of the heads or a property of the pattern that was printed to
% measure them, which is the one thing that decides whether the number is
% worth carrying over to a printed image.
runWidths = unique([groups(isMeasure).runWidth]);
result.separationByArmWidth = nan(size(runWidths));
result.armWidths = runWidths;
for k = 1:numel(runWidths)
    chosen = [groups(isMeasure & [groups.runWidth] == runWidths(k)).separationPixels];
    chosen = chosen(isfinite(chosen));
    if(~isempty(chosen))
        result.separationByArmWidth(k) = mean(chosen)*micronsPerPixel ...
            -result.controlOffsetMicrons;
    end
end
if(numel(runWidths) > 1 && all(isfinite(result.separationByArmWidth)))
    result.featureDependenceMicrons = result.separationByArmWidth(end) ...
        -result.separationByArmWidth(1);
end

random = pqRandomUncertainty(measureValues,controlValues)*micronsPerPixel;
result.randomUncertaintyMicrons = random;
result.uncertaintyMicrons = random+result.inkBiasBoundMicrons;

result.reasons = [result.reasons ...
    pqChecks(result,arms,groups,measureValues,gain,options,micronsPerPixel)];
result.valid = isempty(result.reasons) && isfinite(result.separationMicrons);
if(~result.valid)
    writeToDebugLog(sprintf('Split-X band %s rejected: %s',pattern.joinName, ...
        strjoin(result.reasons,', ')),'warning')
end
end

% =======================================================================

function arms = pqMeasureArms(grey,pattern,offset,amplitude,noise,options)
arms = struct('index',{},'owner',{},'group',{},'block',{},'mark',{}, ...
    'slope',{},'runWidth',{},'fit',{},'measured',{},'width',{}, ...
    'slopeError',{},'maximumExcursion',{});
for k = 1:numel(pattern.arms)
    arm = pattern.arms(k);
    % A wider arm needs a wider window to integrate over, and a narrow one
    % gains nothing from a wide window but noise.
    measured = pqArmCentres(grey,arm.rows+offset(1),arm.centres+offset(2), ...
        options.halfWindow,amplitude(arm.owner), ...
        struct('measureHalfWidth',ceil(arm.runWidth/2)+options.measureMargin, ...
        'noise',noise));
    good = measured.valid;
    fit = pqRobustLineFit(measured.rows(good),measured.centre(good));
    arms(k).index = k;
    arms(k).owner = arm.owner;
    arms(k).group = arm.group;
    arms(k).block = arm.block;
    arms(k).mark = arm.mark;
    arms(k).slope = arm.slope;
    arms(k).runWidth = arm.runWidth;
    arms(k).fit = fit;
    arms(k).measured = measured;
    arms(k).width = median(measured.width(good));
    arms(k).slopeError = fit.slope-arm.slope;
    arms(k).maximumExcursion = max(abs(measured.centre(good) ...
        -(arm.centres(good)'+offset(2))));
end
end

function [groups,capture] = pqMeasureGroups(pattern,arms,options)
% Each group is three marks. The two outer ones are one head and the middle
% one the other, so the mean of the outer centres is that head's position at
% the height of the middle mark, and the difference of the two is the
% separation. Taking the mean rather than one of them is what makes a scan
% that drifts sideways down the band cancel instead of count.
groups = struct('kind',{},'group',{},'block',{},'runWidth',{}, ...
    'separationPixels',{},'downWebPixels',{},'apexOuter',{},'apexMiddle',{}, ...
    'reason',{});
capture = 0;
for k = 1:numel(pattern.measurements)
    measurement = pattern.measurements(k);
    reasons = {};
    outer = zeros(2,2);
    for side = 1:2
        [outer(side,:),reason] = pqApex( ...
            arms(pattern.marks(measurement.outer(side)).arms),options);
        if(~isempty(reason))
            reasons{end+1} = reason;                             %#ok<AGROW>
        end
    end
    [middle,reason] = pqApex(arms(pattern.marks(measurement.middle).arms),options);
    if(~isempty(reason))
        reasons{end+1} = reason;                                 %#ok<AGROW>
    end
    groups(k).kind = measurement.kind;
    groups(k).group = measurement.group;
    groups(k).block = measurement.block;
    groups(k).runWidth = measurement.runWidth;
    groups(k).apexOuter = outer;
    groups(k).apexMiddle = middle;
    groups(k).reason = strjoin(unique(reasons),' ');
    if(isempty(groups(k).reason))
        groups(k).separationPixels = measurement.sign ...
            *(middle(1)-mean(outer(:,1)));
        groups(k).downWebPixels = measurement.sign ...
            *(middle(2)-mean(outer(:,2)));
    else
        groups(k).separationPixels = NaN;
        groups(k).downWebPixels = NaN;
    end
    marks = [measurement.outer measurement.middle];
    for mark = marks
        capture = max(capture, ...
            max([arms(pattern.marks(mark).arms).maximumExcursion]));
    end
end
end

function [apex,reason] = pqApex(pair,options)
% Where the two fitted lines of an arm pair cross. Neither line is printed
% all the way to the crossing, which is the point: the two heads can be a
% long way out without their ink ever touching.
apex = [NaN NaN];
reason = '';
first = pair(1).fit;
second = pair(2).fit;
% How many rows an arm needs is only a question of whether there is still an
% arm there. Twenty rows of a sixty row arm fit a line nearly as well as
% sixty do - the scatter divided by the root of the count is what matters,
% and that is already carried through into the spread between the groups and
% into the uncertainty. So this threshold is set low, where it means the arm
% has gone, and the question of whether what is left was good enough is
% settled on the evidence further down rather than by a rule here.
needed = max(options.minimumArmPointsFloor, ...
    options.minimumArmFraction*max(numel(first.inlier),numel(second.inlier)));
if(first.count < needed || second.count < needed)
    reason = 'fewPoints';
    return
end
if(first.sigma > options.maximumArmSigma || second.sigma > options.maximumArmSigma)
    reason = 'armScatter';
    return
end
separation = first.slope-second.slope;
if(abs(separation) < options.minimumSlopeSeparation)
    reason = 'armsParallel';
    return
end
firstOffset = first.intercept-first.slope*first.yReference;
secondOffset = second.intercept-second.slope*second.yReference;
y = (secondOffset-firstOffset)/separation;
x = first.slope*y+firstOffset;
apex = [x y];
end

function random = pqRandomUncertainty(measureValues,controlValues)
% The standard error of the group values, with the control's own standard
% error added because it has been subtracted from them.
random = std(measureValues)/sqrt(numel(measureValues));
if(numel(controlValues) > 1)
    random = sqrt(random^2+(std(controlValues)/sqrt(numel(controlValues)))^2);
end
end

function reasons = pqChecks(result,arms,groups,measureValues,gain,options,micronsPerPixel)
reasons = {};
badGroups = sum(~isfinite([groups(strcmp({groups.kind},'measure')).separationPixels]));
if(badGroups > 0)
    reasons{end+1} = 'groupLost';
end
if(numel(measureValues) > 1 ...
        && std(measureValues)*micronsPerPixel > options.maximumGroupSpreadMicrons)
    reasons{end+1} = 'groupSpread';
end
if(abs(result.controlOffsetMicrons) > options.maximumControlOffsetMicrons)
    reasons{end+1} = 'controlOffset';
end
if(result.capture > options.halfWindow-options.captureMarginPixels)
    reasons{end+1} = 'outOfRange';
end
% Relative tilt between the two heads. A tilted scan tilts every arm of
% both heads by the same amount and is not a fault, so only the difference
% between the heads is tested.
tiltA = mean([arms([arms.owner] == 1).slopeError]);
tiltB = mean([arms([arms.owner] == 2).slopeError]);
if(abs(tiltB-tiltA) > options.maximumRelativeTilt)
    reasons{end+1} = 'headTilt';
end
% The witness has to be readable, and it has to agree with the arms about
% how much more ink one head is laying down than the other.
if(any(~isfinite([gain.growth])) ...
        || any([gain.spread] > options.maximumWitnessSpread) ...
        || any([gain.count] < options.minimumWitnessFeatures))
    reasons{end+1} = 'witnessUnreliable';
elseif(abs(result.armGrowthDifferencePixels-result.growthDifferencePixels) ...
        > options.maximumWitnessDisagreement)
    reasons{end+1} = 'witnessDisagrees';
end
% The one that matters. Ink that has grown further on one side of a head
% than the other has moved that head's ink sideways, and no measurement of
% the printed image can tell that from the head itself having moved.
% Only worth saying when the witness could be read at all. A witness damaged
% by dead nozzles reads a growth that is not the ink's, and reporting that as
% an asymmetry would name the wrong fault on a scan that is being refused
% anyway.
if(result.inkBiasBoundMicrons > options.inkAsymmetryToleranceMicrons ...
        && ~any(strcmp(reasons,'witnessUnreliable')))
    reasons{end+1} = 'inkAsymmetry';
end
% Arms of two widths that do not agree mean the ink is not landing in the
% same place on a narrow feature as on a wide one. The band can still say
% where its own ink went, but it can no longer speak for a printed image, so
% it is refused rather than reported.
% The two arm widths are only in disagreement if they disagree by more than
% the measurement can resolve. On a noisy scan they will differ by something;
% calling that feature dependence would be reporting the noise.
featureLimit = max(options.featureDependenceToleranceMicrons, ...
    3*result.randomUncertaintyMicrons);
if(isfinite(result.featureDependenceMicrons) ...
        && abs(result.featureDependenceMicrons) > featureLimit)
    reasons{end+1} = 'featureDependence';
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

function prepared = pqPrepareScanSafely(scan)
try
    prepared = pqPrepareScan(scan);
catch err
    writeToDebugLog(err,'warning')
    prepared = struct('grey',[],'paper',NaN,'noise',NaN,'contrast',NaN, ...
        'method','refused');
end
end

function result = pqEmptyResult(pattern)
result = struct('separationMicrons',NaN,'separationRawMicrons',NaN, ...
    'downWebMicrons',NaN,'uncertaintyMicrons',NaN, ...
    'randomUncertaintyMicrons',NaN,'inkBiasBoundMicrons',NaN, ...
    'inkBiasEstimateMicrons',NaN,'growthDifferencePixels',NaN, ...
    'armGrowthDifferencePixels',NaN,'controlOffsetMicrons',NaN, ...
    'capture',NaN,'featureDependenceMicrons',NaN,'separationByArmWidth',[], ...
    'armWidths',[],'valid',false,'reasons',{{}},'joinName',pattern.joinName, ...
    'headA',pattern.headA,'headB',pattern.headB, ...
    'routingVerified',pattern.routingVerified,'registration',[], ...
    'inkGain',[],'arms',[],'groups',[],'scan',[]);
end

function options = pqSplitXAnalysisDefaults(options)
% halfWindow                  half the window each arm row is measured in.
%                             It sets the capture range: the ink can move
%                             halfWindow minus captureMarginPixels before
%                             the window stops holding all of it
% inkAsymmetryToleranceMicrons
%                             how much ink growth bias the measurement is
%                             allowed to be carrying before it is refused.
%                             Set it to the accuracy the measurement is for
% maximumArmSigma             scatter of the row centres about the fitted
%                             line, pixels, beyond which the arm is not a
%                             straight line of ink any more. It is not a
%                             noise test: a noisy scan still fits a good line
%                             through fifty rows, and whether that line was
%                             good enough is settled by the spread between
%                             the groups and by the uncertainty, on the
%                             evidence rather than in advance
% featureDependenceToleranceMicrons
%                             how far the two arm widths may disagree before
%                             the band is refused as not speaking for a
%                             printed image
defaults = struct( ...
    'halfWindow',16, ...
    'measureMargin',4, ...
    'captureMarginPixels',5, ...
    'minimumRegistration',0.25, ...
    'minimumAmplitudeRatio',0.4, ...
    'minimumArmFraction',0.15, ...
    'minimumArmPointsFloor',12, ...
    'maximumArmSigma',1.0, ...
    'minimumSlopeSeparation',0.5, ...
    'minimumGroups',3, ...
    'maximumGroupSpreadMicrons',3.0, ...
    'maximumControlOffsetMicrons',10.0, ...
    'maximumRelativeTilt',0.003, ...
    'maximumWitnessSpread',0.35, ...
    'minimumWitnessFeatures',8, ...
    'maximumWitnessDisagreement',0.5, ...
    'inkAsymmetryToleranceMicrons',4.0, ...
    'featureDependenceToleranceMicrons',4.0);
names = fieldnames(defaults);
for k = 1:numel(names)
    if(~isfield(options,names{k}) || isempty(options.(names{k})))
        options.(names{k}) = defaults.(names{k});
    end
end
end

function result = pqAnalyseMultiMark(scan,pattern,options)
% pqAnalyseMultiMark Cross web displacement of head B, from a MultiMark band
%
%   result = pqAnalyseMultiMark(scan,pattern) reads a MultiMark band and
%   returns the signed displacement of head B across the web, in microns. It
%   measures the same thing as pqAnalyseSplitX by a different route, and the
%   two are meant to be run together and compared: they share no line
%   fitting, no diagonal extraction and no apex, so they do not share those
%   ways of being wrong.
%
%   The value reported is the intercept of a straight line through the three
%   baselines, which is the separation a baseline of zero length would have
%   shown. A scanner whose x scale is out by a fraction stretches every
%   baseline in proportion to its length and so tilts that line without
%   moving its intercept, which is why this number does not care about the
%   scanner's scale. result.scaleError is the tilt, and result.controlScale
%   is the same quantity from the same head control pairs, which have no head
%   displacement in them at all. The two disagreeing means something is
%   stretching the scan that is not a simple scale.
if(nargin < 3)
    options = struct;
end
options = pqMultiMarkAnalysisDefaults(options);
micronsPerPixel = pattern.micronsPerPixel;
result = struct('separationMicrons',NaN,'uncertaintyMicrons',NaN, ...
    'randomUncertaintyMicrons',NaN,'inkBiasBoundMicrons',NaN, ...
    'scaleError',NaN,'controlScale',NaN,'lackOfFitMicrons',NaN, ...
    'capture',NaN,'valid',false,'reasons',{{}},'joinName',pattern.joinName, ...
    'headA',pattern.headA,'headB',pattern.headB, ...
    'routingVerified',pattern.routingVerified,'registration',[], ...
    'inkGain',[],'pairs',[],'byRow',[]);

prepared = pqPrepareScanSafely(scan);
if(isempty(prepared.grey))
    result.reasons{end+1} = 'scanRefused';
    return
end
grey = prepared.grey;
[offset,quality] = pqRegisterPattern(grey,prepared.paper,pattern);
result.registration = struct('offset',offset,'quality',quality);
if(quality < options.minimumRegistration)
    result.reasons{end+1} = 'notRegistered';
    return
end

gain = pqInkGain(grey,pattern,offset);
result.inkGain = gain;
amplitude = [gain.amplitude];
if(~all(isfinite(amplitude)) ...
        || min(amplitude) < options.minimumAmplitudeRatio*max(amplitude))
    result.reasons{end+1} = 'missingHead';
    return
end

% ---- every pair of marks ------------------------------------------------
pairs = struct('kind',{},'row',{},'baseline',{},'separation',{}, ...
    'residual',{},'valid',{},'reason',{},'excursion',{});
for k = 1:numel(pattern.pairs)
    pair = pattern.pairs(k);
    left = pqMarkCentre(grey,pair.left.rows+offset(1), ...
        pair.left.columns+offset(2),options.halfWindow,amplitude(pair.ownerLeft));
    right = pqMarkCentre(grey,pair.right.rows+offset(1), ...
        pair.right.columns+offset(2),options.halfWindow,amplitude(pair.ownerRight));
    pairs(k).kind = pair.kind;
    pairs(k).row = pair.row;
    pairs(k).baseline = pair.baseline;
    pairs(k).valid = left.valid && right.valid;
    pairs(k).reason = strtrim([left.reason ' ' right.reason]);
    if(pairs(k).valid)
        pairs(k).separation = right.centre-left.centre;
        pairs(k).residual = pairs(k).separation-pair.baseline;
        pairs(k).excursion = max( ...
            abs(left.centre-mean(pair.left.columns+offset(2))), ...
            abs(right.centre-mean(pair.right.columns+offset(2))));
    else
        pairs(k).separation = NaN;
        pairs(k).residual = NaN;
        pairs(k).excursion = NaN;
    end
end
result.pairs = pairs;
result.capture = max([pairs.excursion]);

% ---- a line through the baselines, one row at a time --------------------
isMeasure = strcmp({pairs.kind},'measure');
rows = unique([pairs(isMeasure).row]);
byRow = struct('row',{},'displacement',{},'scale',{},'lackOfFit',{});
for k = 1:numel(rows)
    chosen = pairs(isMeasure & [pairs.row] == rows(k) & [pairs.valid]);
    if(numel(chosen) < 2)
        continue
    end
    baseline = [chosen.baseline]';
    residual = [chosen.residual]';
    design = [ones(size(baseline)) baseline];
    coefficients = design\residual;
    byRow(end+1) = struct('row',rows(k),'displacement',coefficients(1), ...
        'scale',coefficients(2),'lackOfFit', ...
        sqrt(mean((residual-design*coefficients).^2))); %#ok<AGROW>
end
result.byRow = byRow;
if(numel(byRow) < 1)
    result.reasons{end+1} = 'fewRows';
    return
end
displacement = [byRow.displacement];
result.separationMicrons = mean(displacement)*micronsPerPixel;
result.scaleError = mean([byRow.scale]);
result.lackOfFitMicrons = mean([byRow.lackOfFit])*micronsPerPixel;

controls = pairs(~isMeasure & [pairs.valid]);
if(~isempty(controls))
    result.controlScale = mean([controls.residual]./[controls.baseline]);
end

growthDifference = gain(2).growth-gain(1).growth;
result.inkBiasBoundMicrons = abs(growthDifference)/2*micronsPerPixel;
if(numel(displacement) > 1)
    result.randomUncertaintyMicrons = std(displacement) ...
        /sqrt(numel(displacement))*micronsPerPixel;
else
    result.randomUncertaintyMicrons = result.lackOfFitMicrons;
end
result.uncertaintyMicrons = result.randomUncertaintyMicrons ...
    +result.inkBiasBoundMicrons;

if(any(~[pairs.valid]))
    result.reasons{end+1} = 'markLost';
end
if(numel(displacement) > 1 && std(displacement)*micronsPerPixel > options.maximumRowSpreadMicrons)
    result.reasons{end+1} = 'rowSpread';
end
if(result.lackOfFitMicrons > options.maximumLackOfFitMicrons)
    result.reasons{end+1} = 'baselinesDisagree';
end
if(isfinite(result.controlScale) ...
        && abs(result.scaleError-result.controlScale) > options.maximumScaleMismatch)
    result.reasons{end+1} = 'scaleMismatch';
end
if(result.capture > options.halfWindow-options.captureMarginPixels)
    result.reasons{end+1} = 'outOfRange';
end
if(any(~isfinite([gain.growth])) || any([gain.count] < options.minimumWitnessFeatures))
    result.reasons{end+1} = 'witnessUnreliable';
end
if(result.inkBiasBoundMicrons > options.inkAsymmetryToleranceMicrons ...
        && ~any(strcmp(result.reasons,'witnessUnreliable')))
    result.reasons{end+1} = 'inkAsymmetry';
end
result.valid = isempty(result.reasons) && isfinite(result.separationMicrons);
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

function options = pqMultiMarkAnalysisDefaults(options)
defaults = struct( ...
    'halfWindow',16, ...
    'captureMarginPixels',5, ...
    'minimumRegistration',0.25, ...
    'minimumAmplitudeRatio',0.4, ...
    'maximumRowSpreadMicrons',3.0, ...
    'maximumLackOfFitMicrons',3.0, ...
    'maximumScaleMismatch',1e-4, ...
    'minimumWitnessFeatures',6, ...
    'inkAsymmetryToleranceMicrons',4.0);
names = fieldnames(defaults);
for k = 1:numel(names)
    if(~isfield(options,names{k}) || isempty(options.(names{k})))
        options.(names{k}) = defaults.(names{k});
    end
end
end

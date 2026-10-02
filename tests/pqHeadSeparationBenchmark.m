function summary = pqHeadSeparationBenchmark(options)
% pqHeadSeparationBenchmark Score Split-X and MultiMark on synthetic scans
%
%   summary = pqHeadSeparationBenchmark() prints, and returns, what the two
%   bands measure on scans whose true displacement, nozzle failures, ink
%   growth and scanner errors are known.
%
%   Every result is scored twice.
%
%   * against the head, which is where the printhead really is;
%   * against the ink, which is where head B's ink really landed relative to
%     head A's once its dot growth has been taken into account.
%
%   The two differ only under one sided dot growth, and the gap between them
%   is not an accident of these patterns. Growing a head's ink further on one
%   side than the other shifts all of that head's ink sideways, and a shift
%   of all of a head's ink is exactly what a displaced head produces. No
%   measurement of a printed image can separate them, so none of these bands
%   can be asked to. What they can be asked is to get the ink right, to say
%   when the ink and the head might have parted company, and to refuse when
%   the ink is not even moving by a single amount. That is what the three
%   scores below count.
%
%   A rejected scan stays in the denominator. Nothing is dropped for being
%   an outlier, no threshold is tuned after seeing a score, and the analyser
%   is never told the true displacement.
if(nargin < 1)
    options = struct;
end
if(~isfield(options,'seeds'))
    options.seeds = 1:3;
end
if(~isfield(options,'displacements'))
    options.displacements = [-250 -150 -75 -50 -25 0 25 50 75 150 250];
end
if(~isfield(options,'tolerance'))
    options.tolerance = 4;      % microns, the accuracy this is wanted to
end
pqSeedRandom(20251002);

join = pqHeadJoins();
join = join(1);
join.routingVerified = true;    % the chart composer's job, asserted here so
                                % that the measurement itself can be scored
patterns = {pqSplitXPattern(join),pqMultiMarkPattern(join)};
names = {'Split-X v3','MultiMark'};

summary = struct('clean',[],'stress',[],'names',{names}, ...
    'tolerance',options.tolerance);

% ---- clean scans, across the measuring range ---------------------------
fprintf('\nClean scans, %d displacements x %d seeds\n',...
    numel(options.displacements),numel(options.seeds));
clean = struct('pattern',{},'displacement',{},'seed',{},'measured',{}, ...
    'valid',{},'uncertainty',{},'reasons',{});
for p = 1:numel(patterns)
    for d = options.displacements
        for seed = options.seeds
            condition = struct('displacementMicrons',d,'seed',seed, ...
                'samplePhase',[0 0.37*mod(seed,3)]);
            scan = pqSimulateHeadSeparation(patterns{p},condition);
            result = measureHeadSeparation(scan,patterns{p});
            clean(end+1) = struct('pattern',p,'displacement',d,'seed',seed, ...
                'measured',result.separationMicrons,'valid',result.valid, ...
                'uncertainty',result.uncertaintyMicrons, ...
                'reasons',{result.reasons}); %#ok<AGROW>
        end
    end
end
summary.clean = clean;
pqReportClean(clean,names,options);

% ---- stress ------------------------------------------------------------
conditions = pqHeadSeparationConditions(50);
fprintf('\nStress, %d conditions x %d seeds, true head displacement +50 um\n', ...
    numel(conditions),numel(options.seeds));
stress = struct('pattern',{},'name',{},'seed',{},'measured',{},'valid',{}, ...
    'headError',{},'inkError',{},'featureDependent',{},'reasons',{});
for p = 1:numel(patterns)
    for k = 1:numel(conditions)
        for seed = options.seeds
            condition = conditions(k).condition;
            condition.seed = seed;
            scan = pqSimulateHeadSeparation(patterns{p},condition);
            result = measureHeadSeparation(scan,patterns{p});
            inkTruth = 50+conditions(k).inkOffsetPixels ...
                *patterns{p}.micronsPerPixel;
            stress(end+1) = struct('pattern',p,'name',conditions(k).name, ...
                'seed',seed,'measured',result.separationMicrons, ...
                'valid',result.valid, ...
                'headError',result.separationMicrons-50, ...
                'inkError',result.separationMicrons-inkTruth, ...
                'featureDependent',conditions(k).featureDependent, ...
                'reasons',{result.reasons}); %#ok<AGROW>
        end
    end
end
summary.stress = stress;
pqReportStress(stress,names,options);
end

function pqReportClean(clean,names,options)
fprintf('\n%-12s %8s %8s %8s %8s %8s %8s\n','pattern','bias','MAE','95th','max','repeat','valid');
for p = 1:numel(names)
    chosen = clean([clean.pattern] == p);
    error = [chosen.measured]-[chosen.displacement];
    valid = [chosen.valid];
    finite = isfinite(error);
    repeat = pqPooledSpread([chosen.measured],[chosen.displacement]);
    fprintf('%-12s %+8.2f %8.2f %8.2f %8.2f %8.2f %7.0f%%\n',names{p}, ...
        mean(error(finite)),mean(abs(error(finite))), ...
        pqPercentile(abs(error(finite)),95),max(abs(error(finite))), ...
        repeat,100*mean(valid));
end
fprintf('microns. bias is signed, so a sign error cannot hide in the MAE.\n');
fprintf('repeat is the pooled standard deviation of repeats at one displacement.\n');
end

function pqReportStress(stress,names,options)
for p = 1:numel(names)
    fprintf('\n%s\n',names{p});
    fprintf('%-34s %9s %9s %9s %6s  %s\n','condition','measured', ...
        'err(head)','err(ink)','valid','reasons');
    chosen = stress([stress.pattern] == p);
    conditionNames = unique({chosen.name},'stable');
    for k = 1:numel(conditionNames)
        here = chosen(strcmp({chosen.name},conditionNames{k}));
        reasons = unique([here.reasons]);
        fprintf('%-34s %+9.2f %+9.2f %+9.2f %5.0f%%  %s\n', ...
            conditionNames{k},pqMeanFinite([here.measured]), ...
            pqMeanFinite([here.headError]),pqMeanFinite([here.inkError]), ...
            100*mean([here.valid]),strjoin(reasons,','));
    end
    [correct,falseValid,rejected,missed] = pqScore(chosen,options.tolerance);
    fprintf(['  against the ink: %d correct, %d accepted but wrong, ' ...
        '%d refused, out of %d\n'],correct,falseValid,rejected,numel(chosen));
    fprintf(['  against the head: %d of the accepted ones are more than ' ...
        '%g um from where the head is\n'],missed,options.tolerance);
end
end

function [correct,falseValid,rejected,missed] = pqScore(chosen,tolerance)
correct = 0; falseValid = 0; rejected = 0; missed = 0;
for k = 1:numel(chosen)
    if(~chosen(k).valid)
        rejected = rejected+1;
        continue
    end
    if(chosen(k).featureDependent)
        % Accepted a reading that cannot have a single right answer.
        falseValid = falseValid+1;
    elseif(abs(chosen(k).inkError) <= tolerance)
        correct = correct+1;
    else
        falseValid = falseValid+1;
    end
    if(abs(chosen(k).headError) > tolerance)
        missed = missed+1;
    end
end
end

function spread = pqPooledSpread(measured,displacement)
levels = unique(displacement);
total = 0; count = 0;
for k = 1:numel(levels)
    here = measured(displacement == levels(k));
    here = here(isfinite(here));
    if(numel(here) < 2)
        continue
    end
    total = total+sum((here-mean(here)).^2);
    count = count+numel(here)-1;
end
spread = sqrt(total/max(count,1));
end

function value = pqMeanFinite(values)
values = values(isfinite(values));
if(isempty(values))
    value = NaN;
else
    value = mean(values);
end
end

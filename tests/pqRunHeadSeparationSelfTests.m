function failures = pqRunHeadSeparationSelfTests
% pqRunHeadSeparationSelfTests Check the head separation code end to end
%
%   failures = pqRunHeadSeparationSelfTests runs the checks that have to hold
%   whatever the scan looks like: that the simulator puts ink where it says
%   it does, that the measurement is signed and linear, that the pattern's
%   two heads are congruent, that the ink witness reads a growth that was
%   really injected, and that awkward input is refused rather than measured.
failures = 0;
fprintf('\nHead separation self tests\n');
failures = failures+pqCheckRasteriser;
failures = failures+pqCheckLocalProfile;
failures = failures+pqCheckLineFit;
failures = failures+pqCheckPatternSymmetry;
failures = failures+pqCheckSignAndLinearity;
failures = failures+pqCheckWitness;
failures = failures+pqCheckRoutingGate;
failures = failures+pqCheckAwkwardInput;
failures = failures+pqCheckOverlay;
failures = failures+pqCheckTiming;
fprintf('\n%d failures\n',failures);
end

function failures = pqCheckRasteriser
% Area is conserved, and a subpixel shift moves the ink by exactly that.
failures = 0;
% A rectangle 3.8 pixels wide, centred on a pixel boundary so that its edges
% land inside pixels, which is the awkward case.
rect = [10.5 11.5 20.5-1.9 20.5+1.9];
worstHard = 0;
for shift = [0 0.1 0.37 0.5 0.9]
    moved = rect+[0 0 shift shift];
    for sigma = [0 0.8]
        coverage = pqRasteriseRects(moved,[21 41],sigma);
        strip = coverage(11,:);
        centre = sum((1:41).*strip)/sum(strip);
        error = centre-(20.5+shift);
        failures = failures+pqExpect(abs(sum(coverage(:))-3.8) < 1e-6, ...
            sprintf('rasteriser area, shift %.2f sigma %.1f',shift,sigma));
        if(sigma > 0)
            failures = failures+pqExpect(abs(error) < 2e-3, ...
                sprintf('blurred rasteriser centre, shift %.2f (%.5f)', ...
                shift,error));
        else
            worstHard = max(worstHard,abs(error));
        end
    end
end
% And the reason the simulator blurs the ink before the pixel collects it
% rather than filtering the image afterwards: the first moment of a sampled
% hard edged rectangle is not its centre, and a symmetric filter applied
% afterwards leaves that error exactly where it was.
failures = failures+pqExpect(worstHard > 0.01, ...
    sprintf(['a hard edged rectangle sampled without blur is out by %.3f ' ...
    'pixels, which is why blur comes first'],worstHard));
end

function failures = pqCheckLocalProfile
% A sloping background is removed exactly, so it cannot pull the centroid.
failures = 0;
columns = 1:25;
ink = 100*exp(-0.5*((columns-13.3)/1.2).^2);
for slope = [0 0.5 -2]
    strip = 200+slope*(columns-13)-ink;
    [profile,window] = pqLocalProfile(strip,columns,3,6,1);
    centre = sum(window.*profile)/sum(profile);
    failures = failures+pqExpect(abs(centre-13.3) < 5e-3, ...
        sprintf('local profile centre with background slope %g (%.4f)', ...
        slope,centre-13.3));
end
end

function failures = pqCheckLineFit
% Outliers do not move the line, and they are reported rather than hidden.
failures = 0;
pqSeedRandom(7);
y = (1:60)';
x = 100+1.0*y+0.05*randn(60,1);
x([7 23 41]) = x([7 23 41])+4;
fit = pqRobustLineFit(y,x);
failures = failures+pqExpect(abs(fit.slope-1) < 1e-3,'line fit slope');
failures = failures+pqExpect(abs(fit.intercept-(100+mean(y))) < 0.05, ...
    'line fit intercept');
failures = failures+pqExpect(fit.rejected >= 3 && fit.rejected <= 12, ...
    sprintf('line fit reported %d rejected points',fit.rejected));
% Perfect data must not be mistaken for an arm with no good points in it.
clean = pqRobustLineFit(y,100+1.0*y);
failures = failures+pqExpect(clean.count == 60, ...
    sprintf('a noiseless line keeps all its points (%d of 60)',clean.count));
end

function failures = pqCheckPatternSymmetry
% The two heads have to print the same amount of the same shapes in the same
% columns, or symmetric dot gain and blur stop cancelling between them.
failures = 0;
pattern = pqSplitXPattern();
[~,byHead] = pqRenderPattern(pattern);
failures = failures+pqExpect(abs(sum(byHead{1}(:))-sum(byHead{2}(:))) < 1e-6, ...
    'the two heads print the same amount of ink');
failures = failures+pqExpect(~any(byHead{1}(:) > 0.5 & byHead{2}(:) > 0.5), ...
    'no pixel is printed by both heads');
for owner = 1:2
    arms = pattern.arms([pattern.arms.owner] == owner);
    widths = sort(unique([arms.runWidth]));
    slopes = sort(unique([arms.slope]));
    failures = failures+pqExpect(isequal(widths,sort(pattern.options.armRunWidth)), ...
        sprintf('head %d uses both arm widths',owner));
    failures = failures+pqExpect(isequal(slopes,[-1 1]), ...
        sprintf('head %d uses both slopes',owner));
end
end

function failures = pqCheckSignAndLinearity
% A negative displacement reads negative, and reads the same size as the
% matching positive one. Nothing is allowed to fold, wrap or straighten it.
failures = 0;
join = pqHeadJoins(); join = join(1); join.routingVerified = true;
for make = {@pqSplitXPattern,@pqMultiMarkPattern}
    pattern = make{1}(join);
    measured = [];
    truth = [-200 -50 0 50 200];
    for d = truth
        result = measureHeadSeparation(pqSimulateHeadSeparation(pattern, ...
            struct('displacementMicrons',d,'seed',2)),pattern);
        measured(end+1) = result.separationMicrons;              %#ok<AGROW>
        failures = failures+pqExpect(result.valid, ...
            sprintf('%s accepted a clean scan at %+g um',pattern.name,d));
    end
    failures = failures+pqExpect(all(sign(measured(truth ~= 0)) == sign(truth(truth ~= 0))), ...
        sprintf('%s keeps the sign',pattern.name));
    failures = failures+pqExpect(max(abs(measured-truth)) < 4, ...
        sprintf('%s is within 4 um over the range (worst %.2f)', ...
        pattern.name,max(abs(measured-truth))));
    slope = (measured(end)-measured(1))/(truth(end)-truth(1));
    failures = failures+pqExpect(abs(slope-1) < 0.01, ...
        sprintf('%s has unit gain (%.4f)',pattern.name,slope));
end
end

function failures = pqCheckWitness
% The witness has to read back a growth that was really injected, and the
% difference between the heads has to follow the difference in their growth.
failures = 0;
pattern = pqSplitXPattern();
for growth = [0.4 0.8 1.2]
    scan = pqSimulateHeadSeparation(pattern,struct('growthA',growth*[1 1], ...
        'growthB',growth*[1 1],'readNoise',0,'paperVariation',0));
    prepared = pqPrepareScan(scan);
    offset = pqRegisterPattern(prepared.grey,prepared.paper,pattern);
    gain = pqInkGain(prepared.grey,pattern,offset);
    for owner = 1:2
        failures = failures+pqExpect(abs(gain(owner).growth-2*growth) < 0.06, ...
            sprintf('witness reads growth %.1f on head %d as %.3f', ...
            2*growth,owner,gain(owner).growth));
    end
end
% One sided growth on head B of 0.75 moves head B's ink by 0.375 pixels, and
% the measurement should follow the ink. It is not an error of the band: no
% measurement of a printed image can tell a head's ink moving from the head
% moving. docs/head-separation.md.
join = pqHeadJoins(); join = join(1); join.routingVerified = true;
pattern = pqSplitXPattern(join);
result = measureHeadSeparation(pqSimulateHeadSeparation(pattern, ...
    struct('displacementMicrons',50,'growthB',[0 0.75],'seed',2)),pattern);
expected = 50+0.375*pattern.micronsPerPixel;
failures = failures+pqExpect(abs(result.separationMicrons-expected) < 4, ...
    sprintf('one sided growth is measured as the ink moving (%.2f for %.2f)', ...
    result.separationMicrons,expected));
end

function failures = pqCheckRoutingGate
% A chart whose head routing has not been confirmed must not be printable.
failures = 0;
chart = pqHeadSeparationChart(pqHeadJoins());
refused = false;
try
    pqHeadSeparationBitmap(chart);
catch err
    refused = strcmp(err.identifier, ...
        'PrintQuality:pqHeadSeparationBitmap:routingNotVerified');
end
failures = failures+pqExpect(refused,'unverified routing refuses a bitmap');
pattern = pqSplitXPattern();
result = measureHeadSeparation(pqSimulateHeadSeparation(pattern, ...
    struct('displacementMicrons',50)),pattern);
failures = failures+pqExpect(~result.valid ...
    && any(strcmp(result.reasons,'routingNotVerified')), ...
    'unverified routing refuses a measurement');
end

function failures = pqCheckAwkwardInput
% None of these is a scan of a band, and none of them may come back with a
% number attached.
failures = 0;
pattern = pqSplitXPattern();
cases = {'all paper',uint8(235*ones(pattern.size)); ...
    'all ink',uint8(zeros(pattern.size)); ...
    'pure noise',uint8(128+20*randn(pattern.size)); ...
    'too small',uint8(235*ones(50,50)); ...
    'the wrong band',pqSimulateHeadSeparation(pqMultiMarkPattern(), ...
        struct('displacementMicrons',0))};
for k = 1:size(cases,1)
    result = measureHeadSeparation(cases{k,2},pattern);
    failures = failures+pqExpect(~result.valid, ...
        sprintf('%s is refused (%s)',cases{k,1},strjoin(result.reasons,',')));
end
end

function failures = pqCheckOverlay
% The debug figures need a screen, so what they would draw is checked here
% instead. Every field a figure reads is read once, which is where a renamed
% field would bite.
failures = 0;
join = pqHeadJoins(); join = join(1); join.routingVerified = true;
pattern = pqSplitXPattern(join);
scan = pqSimulateHeadSeparation(pattern, ...
    struct('displacementMicrons',-50,'seed',1,'deadNozzlesB',203:210));
result = measureHeadSeparation(scan,pattern);
overlay = pqHeadSeparationOverlay(pattern,result,1);
failures = failures+pqExpect(overlay.found,'the overlay found group 1');
failures = failures+pqExpect(numel(overlay.arms) == 6, ...
    sprintf('the overlay has the six arms of three marks (%d)',numel(overlay.arms)));
failures = failures+pqExpect(isequal(size(overlay.centres),[3 2]), ...
    'the overlay has three virtual centres');
failures = failures+pqExpect(all([overlay.arms.kept] > 20), ...
    'every arm of the overlay kept rows to draw');
failures = failures+pqExpect(any(cellfun(@numel,{overlay.arms.droppedRows}) > 0), ...
    'the overlay can show the rows that were dropped');
failures = failures+pqExpect(~isempty(strfind(overlay.title,'um')), ...
    'the overlay has a title with the measurement in it');
% And a group that is not there must not be invented.
missing = pqHeadSeparationOverlay(pattern,result,99);
failures = failures+pqExpect(~missing.found,'the overlay refuses a group that does not exist');
end

function failures = pqCheckTiming
failures = 0;
pattern = pqSplitXPattern();
scan = pqSimulateHeadSeparation(pattern,struct('displacementMicrons',50));
start = tic;
measureHeadSeparation(scan,pattern);
elapsed = toc(start);
fprintf('  one Split-X band analysed in %.2f s (%d by %d)\n', ...
    elapsed,pattern.size(2),pattern.size(1));
end

function failed = pqExpect(condition,description)
failed = ~condition;
if(failed)
    fprintf('  FAIL  %s\n',description);
else
    fprintf('  ok    %s\n',description);
end
end

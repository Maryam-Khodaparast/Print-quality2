function results = pqCompareChannelSelection(seeds)
% pqCompareChannelSelection Score the new channel selection against the old
%
%   results = pqCompareChannelSelection() runs a battery of synthetic scans
%   with known truth through both selections and prints a table of
%       CNR   - contrast to noise ratio the choice actually delivers
%       eff   - that as a fraction of the best available fixed candidate,
%               so 1.00 means nothing better could have been chosen
%       IoU   - overlap of the printed area mask with the true printed area
%
%   results = pqCompareChannelSelection(1:5) uses more seeds per case.
%
%   Every case here is in the regime the standard deviation cannot handle:
%   faint print, sparse features, uneven illumination, dust, or one channel
%   noisier than the rest. The easy cases are included too, to show the new
%   selection agrees with the old one when the old one was right.
if(nargin < 1)
    seeds = 1:3;
end
here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

cases = pqTestCases();
results = struct('name',{},'legacy',{},'current',{});
fprintf('\n%-42s %-26s %-26s\n','case','standard deviation','contrast to noise');
fprintf('%-42s %-26s %-26s\n','','CNR   eff   IoU  pick','CNR   eff   IoU  pick');
fprintf('%s\n',repmat('-',1,96));

for thisCase = 1:numel(cases)
    legacyScores = [];
    currentScores = [];
    legacyPick = '';
    currentPick = '';
    for seed = seeds
        options = cases(thisCase).options;
        options.seed = seed;
        [scan,clean,inkMask] = pqMakeSyntheticScan(options);
        best = pqBestAvailableCnr(scan,clean,inkMask);

        [legacy,legacyName] = pqScoreSelection(@pqLegacyFindChannel2Use, ...
            @pqLegacySelectChannel,scan,clean,inkMask,best);
        [current,currentName] = pqScoreSelection(@findChannel2Use, ...
            @selectChannel,scan,clean,inkMask,best);
        legacyScores = [legacyScores; legacy]; %#ok<AGROW>
        currentScores = [currentScores; current]; %#ok<AGROW>
        legacyPick = legacyName;
        currentPick = currentName;
    end
    legacy = mean(legacyScores,1);
    current = mean(currentScores,1);
    fprintf('%-42s %5.1f %5.2f %5.2f  %-8s %5.1f %5.2f %5.2f  %-8s\n', ...
        cases(thisCase).name,legacy(1),legacy(2),legacy(3),legacyPick, ...
        current(1),current(2),current(3),currentPick);
    results(thisCase).name = cases(thisCase).name;
    results(thisCase).legacy = legacy;
    results(thisCase).current = current;
end

legacyAll = cat(1,results.legacy);
currentAll = cat(1,results.current);
fprintf('%s\n',repmat('-',1,96));
fprintf('%-42s %5s %5.2f %5.2f %9s %5s %5.2f %5.2f\n','mean over all cases', ...
    '',mean(legacyAll(:,2)),mean(legacyAll(:,3)),'', ...
    '',mean(currentAll(:,2)),mean(currentAll(:,3)));
fprintf('%-42s %11d/%-14d %11d/%d\n','best candidate chosen', ...
    sum(legacyAll(:,2) > 0.99),numel(results), ...
    sum(currentAll(:,2) > 0.99),numel(results));
fprintf('\n');
end

function [scores,pickName] = pqScoreSelection(chooser,masker,scan,clean,inkMask,best)
% CNR the choice delivers, its efficiency against the best available, and
% the overlap of the mask that comes out of the full pipeline
try
    [~,info] = chooser(scan);
    chosenNoisy = pqApplyChoice(scan,info);
    chosenClean = pqApplyChoice(clean,info);
    cnr = pqTrueCnr(chosenClean,chosenNoisy,inkMask);
    pickName = pqShortName(info.method);
catch err
    fprintf('  selection failed: %s\n',err.message);
    scores = [0 0 0];
    pickName = 'failed';
    return
end
try
    [~,mask] = masker(scan);
    intersection = sum(sum(mask & inkMask));
    union = sum(sum(mask | inkMask));
    iou = intersection/max(union,1);
catch
    iou = 0;
end
scores = [cnr cnr/best iou];
end

function best = pqBestAvailableCnr(scan,clean,inkMask)
% The best CNR any of the fixed candidates could deliver on this scan
scanDouble = double(scan);
numberSeps = size(scanDouble,3);
candidates = cell(0,2);
for sep = 1:numberSeps
    candidates(end+1,:) = {scanDouble(:,:,sep),clean(:,:,sep)}; %#ok<AGROW>
end
candidates(end+1,:) = {min(scanDouble,[],3),min(clean,[],3)};
candidates(end+1,:) = {max(scanDouble,[],3),max(clean,[],3)};
candidates(end+1,:) = {mean(scanDouble,3),mean(clean,3)};
best = 0;
for candidate = 1:size(candidates,1)
    best = max(best,pqTrueCnr(candidates{candidate,2}, ...
        candidates{candidate,1},inkMask));
end
end

function short = pqShortName(method)
if(~isempty(strfind(method,'channel ')) && isempty(strfind(method,'mix')) ...
        && isempty(strfind(method,'min')) && isempty(strfind(method,'max')) ...
        && isempty(strfind(method,'mean')))
    short = ['ch' method(end)];
elseif(~isempty(strfind(method,'mix')))
    short = 'mix';
elseif(~isempty(strfind(method,'min')))
    short = 'min';
elseif(~isempty(strfind(method,'max')))
    short = 'max';
else
    short = 'mean';
end
end

function cases = pqTestCases()
% Each case is a scan a print quality rig really does produce
cases = pqCase([],'solid black bars, clean scan', ...
    struct('inkDensity',[0.70 0.70 0.68],'noise',[2 2 2],'feature','bars'));
cases = pqCase(cases,'faint cyan bars, noisy blue channel', ...
    struct('inkDensity',[0.06 0.02 0.005],'noise',[2 3 14],'feature','bars'));
cases = pqCase(cases,'faint yellow bars, noisy blue channel', ...
    struct('inkDensity',[0.004 0.02 0.07],'noise',[2 3 10],'feature','bars'));
cases = pqCase(cases,'fine lines, 1% coverage, noisy blue', ...
    struct('inkDensity',[0.10 0.55 0.08],'noise',[2 2 12],'feature','fineLines'));
cases = pqCase(cases,'30% halftone tint, noisy blue', ...
    struct('tint',0.30,'inkDensity',[0.12 0.12 0.10],'noise',[2 2 10], ...
    'feature','patch'));
cases = pqCase(cases,'illumination gradient of 25 levels', ...
    struct('gradient',25,'inkDensity',[0.10 0.03 0.01],'noise',[3 3 8], ...
    'feature','bars'));
cases = pqCase(cases,'dust on the glass, faint magenta bars', ...
    struct('dustCount',150,'inkDensity',[0.02 0.07 0.015],'noise',[2 2 2], ...
    'feature','bars'));
cases = pqCase(cases,'ink in two channels, shared scanner noise', ...
    struct('inkDensity',[0.10 0.09 0.01],'noise',[4 4 4],'noiseShared',8, ...
    'feature','patch'));
cases = pqCase(cases,'bright feature, noisy blue channel', ...
    struct('brightFeature',true,'inkDensity',[0.03 0.03 0.02], ...
    'noise',[1.5 1.5 6],'feature','patch'));
cases = pqCase(cases,'saturated paper, faint print', ...
    struct('paperLevel',[252 252 250],'inkDensity',[0.05 0.02 0.01], ...
    'noise',[5 5 5],'feature','bars'));
cases = pqCase(cases,'text target, noisy red channel', ...
    struct('inkDensity',[0.10 0.25 0.08],'noise',[12 2 2],'feature','text'));
end

function cases = pqCase(cases,name,options)
if(isempty(cases))
    cases = struct('name',{},'options',{});
end
cases(end+1).name = name;
cases(end).options = options;
end

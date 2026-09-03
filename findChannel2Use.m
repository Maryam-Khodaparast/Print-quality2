function [imageOut,info] = findChannel2Use(imageIn)
% findChannel2Use Select optimum channel or combination of channels from scan
%
%   imageOut = findChannel2Use(imageIn) picks the single channel, or the
%   combination of channels, that separates ink from paper most reliably.
%
%   [imageOut,info] = findChannel2Use(imageIn) also returns the measurements
%   the choice was made on, so that callers do not have to repeat them:
%       info.method     - text description of what was selected
%       info.sep2Use    - channel index, or NaN when a combination was used
%       info.weights    - channel weights of the combination ([] for min/max)
%       info.paper      - paper (background) code value of imageOut
%       info.sigma      - noise standard deviation of imageOut
%       info.contrast   - ink to paper contrast of imageOut
%       info.cnr        - contrast to noise ratio of imageOut
%       info.inkIsDark  - true when the printed feature is darker than paper
%       info.candidates - every candidate that was scored, with its stats
%       info.lowConfidence - true when no channel showed a clear feature
%
%   Selection is by contrast to noise ratio, not by standard deviation.
%   Standard deviation cannot tell ink from noise: a channel carrying
%   scanner noise, a halftone screen, an illumination gradient or dust can
%   have the largest spread while carrying the least usable signal, and a
%   sparse feature such as a fine line has a small standard deviation
%   however clean it is. Contrast to noise ratio measures what actually
%   matters downstream - how far the ink sits from the paper compared with
%   the noise it has to be told apart from.
%
%   The printed area is found once, from whichever channel shows it best,
%   and every candidate is then measured over that same area. See
%   pqChannelStats for the measurements and pqOptimalMix for the combination.
try
    if(~isnumeric(imageIn) && ~islogical(imageIn))
        error('PrintQuality:findChannel2Use:badInput', ...
            'Scan must be a numeric image');
    end
    combinationMargin = 0.20; % a mix must beat the best single channel by 20%
    minimumCnr = 3;           % below this the scan is not worth trusting

    scan = double(imageIn);
    numberSeps = size(scan,3);
    % A noise estimate can never be finer than the quantisation of the data,
    % and a zero estimate would make every contrast to noise ratio infinite
    if(isinteger(imageIn) || islogical(imageIn))
        sigmaFloor = 1/sqrt(12);
    else
        dataRange = max(scan(:))-min(scan(:));
        sigmaFloor = max(dataRange,eps)/255/sqrt(12);
    end

    % Find the printed area, taking it from whichever channel shows most of
    % it. Dust and noise spikes are scattered rather than packed, so they
    % never win this even on a channel the ink does not reach at all. If no
    % channel shows print pixel by pixel, the search is repeated over a box
    % average, where faint print stands clear of the noise.
    referenceMask = [];
    channelPaper = zeros(1,numberSeps);
    channelSigma = zeros(1,numberSeps);
    for detectScale = [1 7]
        printedPixels = 0;
        for sep = 1:numberSeps
            [stats,inkMask] = pqChannelStats(scan(:,:,sep),sigmaFloor, ...
                [],detectScale);
            channelPaper(sep) = stats.paper;
            channelSigma(sep) = stats.sigma;
            if(stats.hasFeature && sum(inkMask(:)) > printedPixels)
                printedPixels = sum(inkMask(:));
                referenceMask = inkMask;
            end
        end
        if(~isempty(referenceMask))
            break
        end
    end
    lowConfidence = isempty(referenceMask);

    % Candidates: every channel on its own, plus the standard neutral and
    % mean combinations when there is more than one channel
    candidates = pqCandidate('channel 1',scan(:,:,1),1,pqUnitWeights(1,numberSeps));
    for sep = 2:numberSeps
        candidates(end+1) = pqCandidate(sprintf('channel %d',sep), ...
            scan(:,:,sep),sep,pqUnitWeights(sep,numberSeps)); %#ok<AGROW>
    end
    numberSingles = numel(candidates);
    if(numberSeps > 1)
        candidates(end+1) = pqCandidate('neutral (min of channels)', ...
            min(scan,[],3),NaN,[]);
        candidates(end+1) = pqCandidate('neutral (max of channels)', ...
            max(scan,[],3),NaN,[]);
        candidates(end+1) = pqCandidate('mean of channels', ...
            mean(scan,3),NaN,ones(1,numberSeps)/numberSeps);

        % A noise whitened mix of the channels. This is the matched filter
        % for ink against correlated scanner noise, so it can beat any
        % single channel when the ink shows up in more than one of them.
        if(~lowConfidence)
            paperMask = pqPaperMask(scan,referenceMask,channelPaper,channelSigma);
            [mixImage,mixWeights] = pqOptimalMix(scan,referenceMask,paperMask);
            if(~isempty(mixImage))
                candidates(end+1) = pqCandidate( ...
                    'noise weighted mix of channels',mixImage,NaN,mixWeights);
            end
        end
    end

    % Score every candidate over the same printed area
    for candidate = 1:numel(candidates)
        candidates(candidate).stats = pqChannelStats( ...
            candidates(candidate).image,sigmaFloor,referenceMask);
    end
    scores = pqScores(candidates);

    % A single channel wins unless a combination is clearly better. Keeping
    % the simple answer when the gain is marginal stops the choice flipping
    % between near equal candidates from one scan to the next.
    [bestSingleScore,chosen] = max(scores(1:numberSingles));
    [bestScore,bestAny] = max(scores);
    if(bestScore > bestSingleScore*(1+combinationMargin))
        chosen = bestAny;
    end

    imageOut = pqMatchClass(candidates(chosen).image,imageIn);
    info = candidates(chosen).stats;
    info.method = candidates(chosen).name;
    info.sep2Use = candidates(chosen).sep2Use;
    info.weights = candidates(chosen).weights;
    % Print that is real reaches a contrast to noise ratio of several times
    % this. A scan whose best candidate does not is either badly exposed or
    % has nothing printed on it, and the caller is told so rather than being
    % handed a choice that looks as authoritative as any other.
    info.lowConfidence = lowConfidence || info.cnr < minimumCnr;
    info.candidates = rmfield(candidates,'image');

    writeToDebugLog(['Channel selected from scan = ' info.method ...
        ' (' pqReportScores(candidates) ')'],'info')
    if(info.lowConfidence)
        writeToDebugLog(sprintf(['No channel showed a clear printed ' ...
            'feature (best contrast to noise ratio %.1f), the selection ' ...
            'is low confidence'],info.cnr),'warning')
    end
catch err
    writeToDebugLog(err,'error');
    if(strncmp(err.identifier,'MATLAB',6))
        errorTxt = 'Unable to select channel to use in scan';
    else
        errorTxt = err.message;
    end
    error('%s',errorTxt);
end
end

function weights = pqUnitWeights(sep,numberSeps)
weights = zeros(1,numberSeps);
weights(sep) = 1;
end

function candidate = pqCandidate(name,image,sep2Use,weights)
candidate.name = name;
candidate.image = image;
candidate.sep2Use = sep2Use;
candidate.weights = weights;
candidate.stats = [];
end

function paperMask = pqPaperMask(scan,referenceMask,channelPaper,channelSigma)
% Paper is what is neither printed, nor next to something printed, nor off
% its own paper level in any channel. Excluding dust and specks here matters
% because this is where the noise of the scan is measured from.
paperMask = conv2(ones(5,1),ones(1,5),double(referenceMask),'same') == 0;
for channel = 1:size(scan,3)
    paperMask = paperMask & abs(scan(:,:,channel)-channelPaper(channel)) ...
        < max(4*channelSigma(channel),2);
end
end

function scores = pqScores(candidates)
scores = -Inf(1,numel(candidates));
for candidate = 1:numel(candidates)
    scores(candidate) = candidates(candidate).stats.cnr;
end
end

function txt = pqReportScores(candidates)
parts = cell(1,numel(candidates));
for candidate = 1:numel(candidates)
    parts{candidate} = sprintf('%s: CNR %.1f contrast %.1f noise %.2f', ...
        candidates(candidate).name,candidates(candidate).stats.cnr, ...
        candidates(candidate).stats.contrast,candidates(candidate).stats.sigma);
end
txt = strjoin(parts,'; ');
end

function imageOut = pqMatchClass(image,imageIn)
if(isinteger(imageIn))
    topEnd = double(intmax(class(imageIn)));
    imageOut = cast(min(topEnd,max(0,round(image))),class(imageIn));
else
    imageOut = image;
end
end

function [imageGreyscale,mask,paper] = selectChannel(imageIn)
% selectChannel Use the shared channel chooser, then find the paper value
% and the printed area of the channel it returns
%
%   [imageGreyscale,mask,paper] = selectChannel(imageIn)
%       imageGreyscale - chosen channel as double, printed feature dark
%       mask           - true over the printed area
%       paper          - paper code value, measured over the unprinted area
%
%   A scan whose best channel does not lift the print clear of the noise is
%   refused rather than masked, see findChannel2Use.
%
%   The paper value, the contrast and the noise all come back from
%   findChannel2Use, which has already measured them to make its choice, so
%   they are not measured twice. The mask threshold is set from the noise as
%   well as the contrast: on a noisy scan a fixed fraction of contrast lets
%   paper noise through into the mask, which is what makes a mask look
%   speckled and pushes the paper value out.
try
    if(isa(imageIn,'uint16'))
        imageIn = uint8(double(imageIn)/257);
    end
    [chosenChannel,info] = findChannel2Use(imageIn);
    if(info.lowConfidence)
        % Nothing on this scan stands clear of its own noise. A mask built
        % from it would be a mask of noise, and every measurement taken from
        % that mask would look like a real reading, so the scan is refused
        % instead.
        error('PrintQuality:selectChannel:noFeature', ...
            ['No channel of this scan shows print clear of its noise ' ...
            '(best contrast to noise ratio %.1f)'],info.cnr);
    end
    imageGreyscale = double(chosenChannel);
    paper = info.paper;
    contrast = info.contrast;
    noise = info.sigma;

    % Invert if the feature is brighter than paper. Reflecting about the
    % paper value leaves the paper value itself unchanged.
    if(~info.inkIsDark)
        imageGreyscale = min(255,max(0,2*paper-imageGreyscale));
    end

    % Printed area mask from the difference to paper. Taken only on the
    % dark side of paper, so that bright specks cannot enter it, and thinned
    % of isolated pixels, so that dust and noise spikes cannot either.
    maskThreshold = max([4*noise 0.15*contrast 2]);
    if(maskThreshold > 0.6*contrast)
        writeToDebugLog(['Scan noise is high against its contrast ' ...
            '(CNR ' num2str(info.cnr,'%.1f') '), mask may be unreliable'], ...
            'warning')
        maskThreshold = 0.6*contrast;
    end
    mask = pqDenseRegions((paper-imageGreyscale) > maskThreshold);
    if(~any(mask(:)) || ~any(~mask(:)))
        error('PrintQuality:selectChannel:noFeature', ...
            'Unable to separate the printed feature from the paper');
    end
    % Refine the paper value using the mask
    paper = mean(imageGreyscale(~mask));
catch err
    writeToDebugLog(err,'error')
    error('MASK Unable to process scan for head separation feature')
end
end

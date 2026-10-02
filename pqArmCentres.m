function measured = pqArmCentres(grey,rows,centres,halfWindow,amplitude,options)
% pqArmCentres Centre and width of the ink in each row of a diagonal arm
%
%   measured = pqArmCentres(grey,rows,centres,halfWindow,amplitude) measures,
%   for every row of an arm, where its ink sits across the web and how wide
%   it is. centres is the nominal centre column in each row.
%
%   The centre is the centroid of the ink over a window centred on the ink
%   itself, not on the nominal position: with the window centred on the ink,
%   the same amount of blur tail is cut off each side, and an error in the
%   background multiplies a quantity that sums to zero. Both of those would
%   otherwise be a bias, and a bias that differed between the two heads
%   because only one of them has moved. The background under the row is
%   removed as a sloping line rather than as a level, see pqLocalProfile.
%
%   The width is the integral of the ink divided by the amplitude of solid
%   ink, which is the width the ink would have if it had hard edges. Blur
%   does not change it, because blur moves ink about but does not add any.
%   That is what makes it a measurement of how far the ink has grown past
%   the edge the nozzle aimed at.
%
%   measured.valid is false for a row whose ink is missing - a dead nozzle,
%   or an arm running off the scan - and measured.reason says which. The
%   rows are kept rather than deleted so the debug figures can show what was
%   dropped and why.
if(nargin < 6)
    options = struct;
end
if(~isfield(options,'flankPixels'))
    options.flankPixels = 3;     % background is fitted over this many pixels
end                              % at each end of the window
if(~isfield(options,'measureHalfWidth'))
    % Smallest window the ink is integrated over. The real one is set from
    % how far the ink actually spreads, measured on the scan itself: a
    % heavily blurred scan needs a wider window than a sharp one, and a
    % window that cuts the blur off cuts more off one side than the other
    % whenever the ink does not sit on a whole pixel. That is a bias, and it
    % is a different bias for the head that has moved than for the one that
    % has not.
    options.measureHalfWidth = 6;
end
if(~isfield(options,'spreadsToKeep'))
    options.spreadsToKeep = 4;
end
if(~isfield(options,'maximumInkDeficit'))
    % A row that has lost one column of its run still holds most of its ink -
    % two thirds of a three column run, six sevenths of a seven column one -
    % but its centre has moved as much as half a pixel. So the test is not
    % how much ink is left but how much is missing, against the rows of this
    % arm that are undamaged. One part in twelve catches a whole column lost
    % from the widest arm here, and is many times the spread between rows of
    % a healthy arm.
    options.maximumInkDeficit = 0.08;
end
if(~isfield(options,'healthyPercentile'))
    % Which rows count as undamaged. Not the median: with a tenth of the
    % nozzles dead, a third of the rows of a three column arm have lost
    % something, and the median has lost something too. The upper part of
    % the distribution is still made of healthy rows.
    options.healthyPercentile = 85;
end
if(~isfield(options,'noise'))
    % Noise of one pixel of the scan. The deficit test has to be loose enough
    % not to throw away healthy rows of a faint or noisy scan, where the ink
    % of a row is itself uncertain, and the only way to know how loose is to
    % know the noise. Leaving this at zero makes the test the flat deficit
    % above, which is right only for a clean scan.
    options.noise = 0;
end
if(~isfield(options,'inkDeviations'))
    options.inkDeviations = 5;
end
if(~isfield(options,'endRowsToDrop'))
    % The rows at each end of a run of an arm have a neighbouring row on one
    % side only, so the ink that blur spills into them is one sided and pulls
    % their centre. Everywhere else it cancels. How far in that reaches
    % depends on how blurred the scan is, and six rows covers a scan blurred
    % far beyond anything a working scanner produces.
    options.endRowsToDrop = 4;
end

numberRows = numel(rows);
measured = struct( ...
    'rows',rows(:),'nominal',centres(:), ...
    'centre',nan(numberRows,1),'width',nan(numberRows,1), ...
    'ink',zeros(numberRows,1),'spread',nan(numberRows,1), ...
    'valid',false(numberRows,1), ...
    'reason',{repmat({''},numberRows,1)});
[imageRows,imageColumns] = size(grey);

% Two passes. The first measures over the whole window, which is wide enough
% to hold the ink however far the head has moved, and only has to find it.
% The second measures over a narrow window, placed from where the first pass
% found the arm, where all of the ink is and almost none of the noise.
%
% Where the window goes is decided once for the whole arm and not row by
% row. A window has to sit on whole pixels, so placing it means rounding, and
% rounding is a step: a row whose ink sits near half way between two pixels
% has its window thrown from one to the other by noise, and which way it goes
% depends on the noise itself. Measuring from the window it lands in then
% leans the answer, by an amount that grows with the noise and vanishes when
% the ink sits squarely on a pixel - so the two heads of a band, which sit at
% different fractions of a pixel, lean by different amounts and the leaning
% does not cancel. Deciding it once per arm, from the middle of fifty rows,
% takes the noise on that decision down by the root of fifty and the throw
% with it.
widest = halfWindow-options.flankPixels;
measureHalfWidth = [widest widest];
armOffset = 0;
for pass = 1:2
    for k = 1:numberRows
        row = rows(k);
        if(row < 1 || row > imageRows)
            measured.reason{k} = 'offScan';
            continue
        end
        middle = round(centres(k)+armOffset);
        window = middle-halfWindow:middle+halfWindow;
        if(window(1) < 1 || window(end) > imageColumns)
            measured.reason{k} = 'offScan';
            continue
        end
        strip = double(grey(row,window));
        [profile,inside] = pqLocalProfile(strip,window,options.flankPixels, ...
            measureHalfWidth(pass),1);
        total = sum(profile);
        if(total <= 0)
            measured.centre(k) = NaN;
            measured.ink(k) = 0;
            continue
        end
        measured.ink(k) = total;
        measured.centre(k) = sum(inside.*profile)/total;
        measured.width(k) = total/amplitude;
        if(pass == 1)
            measured.spread(k) = sqrt(max(0, ...
                sum(profile.*(inside-measured.centre(k)).^2)/total));
        end
    end
end

% A row with less ink than the healthy rows of the same arm has lost a
% nozzle, or part of one. The comparison is against this arm's own rows, so
% a light ink laydown is not mistaken for damage.
% An arm is printed in runs of consecutive rows, with the hole in the middle
% of its mark between them, so it has four ends and not two.
atEnd = false(numberRows,1);
breaks = [0 find(diff(rows(:)') ~= 1) numberRows];
for k = 1:numel(breaks)-1
    first = breaks(k)+1;
    last = breaks(k+1);
    drop = min(options.endRowsToDrop,floor((last-first+1)/3));
    atEnd(first:first+drop-1) = true;
    atEnd(last-drop+1:last) = true;
end

present = measured.ink(measured.ink > 0);
reference = pqPercentile(present,options.healthyPercentile);
% The ink of a row is a sum over the measuring window of the scan minus a
% background fitted to the pixels at the ends of it, so its uncertainty
% grows with the window and shrinks with the number of pixels the background
% was taken from.
windowPixels = 2*measureHalfWidth(2)+1;
inkNoise = options.noise*sqrt(windowPixels) ...
    *sqrt(1+windowPixels/(2*options.flankPixels));
floorInk = reference-max(options.maximumInkDeficit*reference, ...
    options.inkDeviations*inkNoise);
for k = 1:numberRows
    if(~isempty(measured.reason{k}))
        continue
    end
    if(~isfinite(measured.centre(k)) ...
            || measured.ink(k) < floorInk)
        measured.reason{k} = 'noInk';
    elseif(atEnd(k))
        measured.reason{k} = 'armEnd';
    else
        measured.valid(k) = true;
    end
end
end

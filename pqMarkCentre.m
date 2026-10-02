function mark = pqMarkCentre(grey,rows,columns,halfWindow,amplitude,measureHalfWidth)
% pqMarkCentre Centre and width of one solid mark, to a fraction of a pixel
%
%   mark = pqMarkCentre(grey,rows,columns,halfWindow,amplitude,
%   measureHalfWidth) averages the mark down its length, removes the sloping
%   background from the paper either side of it, and takes the centroid.
%
%   Two passes: the first finds the mark anywhere within halfWindow of where
%   it was supposed to be, the second measures it over a narrow window
%   centred on where it actually is. A head a long way out of position is
%   then measured on its own ink rather than on the paper beside it, and the
%   narrow window keeps the noise of the far pixels out of the answer.
if(nargin < 6 || isempty(measureHalfWidth))
    measureHalfWidth = ceil(numel(columns)/2)+4;
end
mark = struct('centre',NaN,'width',NaN,'ink',0,'valid',false,'reason','');
flankPixels = 3;
middle = round(mean(columns));
rows = rows(rows >= 1 & rows <= size(grey,1));
if(isempty(rows))
    mark.reason = 'offScan';
    return
end
halves = [halfWindow-flankPixels measureHalfWidth];
for pass = 1:2
    window = middle-halfWindow:middle+halfWindow;
    if(window(1) < 1 || window(end) > size(grey,2))
        mark.reason = 'offScan';
        return
    end
    strip = mean(double(grey(rows,window)),1);
    [profile,inside] = pqLocalProfile(strip,window,flankPixels,halves(pass),1);
    total = sum(profile);
    if(~isfinite(total) || total <= 0)
        mark.reason = 'noInk';
        return
    end
    centre = sum(inside.*profile)/total;
    if(pass == 1)
        middle = round(centre);
        continue
    end
    mark.centre = centre;
    mark.ink = total;
    mark.width = total/amplitude;
    mark.valid = true;
end
end

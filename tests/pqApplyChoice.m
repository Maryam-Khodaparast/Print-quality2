function plane = pqApplyChoice(scan,info)
% pqApplyChoice Rebuild the plane a selection chose, from any scan
%
%   Lets the same choice be applied to the noise free version of a scan, so
%   that what the selection picked can be scored against the truth.
scan = double(scan);
if(~isempty(info.weights))
    plane = zeros(size(scan,1),size(scan,2));
    for channel = 1:numel(info.weights)
        plane = plane+info.weights(channel)*scan(:,:,channel);
    end
elseif(~isempty(strfind(info.method,'min')))
    plane = min(scan,[],3);
elseif(~isempty(strfind(info.method,'max')))
    plane = max(scan,[],3);
else
    error('pqApplyChoice: cannot rebuild "%s"',info.method);
end
end

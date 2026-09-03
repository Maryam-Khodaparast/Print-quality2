function sample = pqSample(data,maximumSamples)
% pqSample Thin a large set of values down to a workable number
%
%   A median or a percentile of a few hundred thousand pixels is as good as
%   one of ten million, and costs a fraction of the time on a full size
%   scan. The step is taken prime so that it cannot fall into step with a
%   halftone screen and sample only the dots, or only the gaps.
if(nargin < 2)
    maximumSamples = 2e5;
end
data = data(:);
if(numel(data) <= maximumSamples)
    sample = data;
    return
end
step = ceil(numel(data)/maximumSamples);
while(~isprime(step))
    step = step+1;
end
sample = data(1:step:end);
end

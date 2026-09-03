function value = pqPercentile(data,percent)
% pqPercentile Percentile of the finite elements of data, no toolbox needed
%
%   Large sets are thinned first, see pqSample.
data = pqSample(double(data(isfinite(data))));
data = sort(data);
if(isempty(data))
    value = NaN;
    return
end
index = min(numel(data),max(1,round(percent/100*numel(data))));
value = data(index);
end

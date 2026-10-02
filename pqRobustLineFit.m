function fit = pqRobustLineFit(y,x,options)
% pqRobustLineFit Fit x = slope*y + intercept, down weighting outliers
%
%   fit = pqRobustLineFit(y,x) fits a straight line by iteratively reweighted
%   least squares with Huber weights, so a handful of rows thrown off by a
%   partly firing nozzle or a speck of dirt move the line by very little
%   without having to be found and removed first.
%
%   fit.inlier marks the points the final fit still trusts, and fit.rejected
%   counts the rest. Nothing is deleted: the caller keeps the points and the
%   reasons so a figure can show what the fit ignored.
%
%   fit.sigma is a robust scatter of the residuals, and fit.slopeError and
%   fit.interceptError are the standard errors that follow from it. The
%   intercept is taken about the mean of y, which is where a straight line is
%   best determined, and pqArmApex moves it from there to wherever it is
%   wanted.
if(nargin < 3)
    options = struct;
end
if(~isfield(options,'iterations'))
    options.iterations = 5;
end
if(~isfield(options,'huber'))
    options.huber = 2.0;        % residuals beyond this many sigma lose weight
end
if(~isfield(options,'minimumSigma'))
    % Floor on the scale the outliers are judged against. Without it, points
    % that agree with each other perfectly drive the scale to zero and then
    % every point that is not exactly on the line - the last digit of a code
    % value is enough - is an outlier, and the fit throws away all of its
    % data at the moment the data is at its best. The floor is a hundredth of
    % a pixel, which is finer than any of this is measuring to.
    options.minimumSigma = 0.01;
end
y = y(:); x = x(:);
fit = struct('slope',NaN,'intercept',NaN,'yReference',NaN,'sigma',NaN, ...
    'slopeError',NaN,'interceptError',NaN,'inlier',false(size(y)), ...
    'rejected',numel(y),'count',0);
good = isfinite(y) & isfinite(x);
if(sum(good) < 3)
    return
end
y = y(good); x = x(good);
fit.yReference = mean(y);
centred = y-fit.yReference;

weight = ones(size(y));
for iteration = 1:options.iterations
    design = [centred ones(size(centred))];
    coefficients = (design'*(weight.*design))\(design'*(weight.*x));
    residual = x-design*coefficients;
    sigma = 1.4826*median(abs(residual-median(residual)));
    if(~isfinite(sigma) || sigma <= 0)
        sigma = std(residual);
    end
    sigma = max(sigma,options.minimumSigma);
    scaled = abs(residual)/(options.huber*sigma);
    weight = min(1,1./max(scaled,1e-6));
end
fit.slope = coefficients(1);
fit.intercept = coefficients(2);
fit.sigma = sigma;
inlier = abs(residual) <= options.huber*sigma;
fit.count = sum(inlier);
fit.rejected = sum(~inlier);
full = false(size(good));
full(good) = inlier;
fit.inlier = full;
if(fit.count > 2)
    spread = sum(centred(inlier).^2);
    fit.slopeError = sigma/sqrt(max(spread,eps));
    fit.interceptError = sigma/sqrt(fit.count);
end
end

function [profile,window,baseline] = pqLocalProfile(strip,columns,flankPixels,measureHalfWidth,polarity)
% pqLocalProfile A feature's profile above its own local background
%
%   [profile,window] = pqLocalProfile(strip,columns,flankPixels,
%   measureHalfWidth,polarity) takes a strip of code values spanning
%   columns, works out the background from the flankPixels at each end of
%   it, and returns the feature standing above that background over the
%   middle measureHalfWidth pixels either side.
%
%   polarity is +1 for a dark feature on a light background - an ink line on
%   paper - and -1 for a light feature on a dark one - a paper gap inside a
%   block of ink. The arithmetic is otherwise identical, which is what makes
%   the two polarities comparable.
%
%   The background is a straight line fitted through both flanks rather than
%   their mean. Scanner illumination and paper shade drift across a band, and
%   a sloping background under a feature is not a harmless offset: the slope
%   multiplies the squared distance from the centre when the centroid is
%   formed, and pulls the measured centre downhill. Removing the slope is
%   what takes the measurement from a couple of microns of scatter to a
%   fraction of one.
%
%   The feature is then integrated over a narrow window and not over the
%   whole strip. The far pixels of a wide window hold no feature and all of
%   the noise, so including them costs accuracy and buys nothing. The wide
%   strip is still needed - it is what lets the feature be found when a head
%   is a long way out, and it is where the background is measured - but only
%   the middle of it is measured over.
middle = round(numel(strip)/2);
flank = [1:flankPixels numel(strip)-flankPixels+1:numel(strip)];
design = [columns(flank)'-columns(middle) ones(numel(flank),1)];
coefficients = design\strip(flank)';
baseline = coefficients(1)*(columns-columns(middle))+coefficients(2);
profile = polarity*(baseline-strip);
inside = abs(columns-columns(middle)) <= measureHalfWidth;
profile = profile(inside);
window = columns(inside);
end

function [cnr,contrast,noise] = pqTrueCnr(cleanPlane,noisyPlane,inkMask)
% pqTrueCnr Contrast to noise ratio of a plane, measured against the truth
%
%   The contrast comes from the noise free scan over the known printed area,
%   and the noise from the difference between the noisy and noise free scan
%   over the paper.
%
%   The noise is a standard deviation with the largest one percent of the
%   residuals trimmed off. Trimming keeps a scattering of dust specks from
%   standing in for the noise of a whole scan, while a plain median of
%   absolute deviations would read a scan clipped at the top of its scale as
%   almost noise free, because most of its paper piles onto one code value
%   while the tail below it stays as wide as ever.
paperMask = ~inkMask;
contrast = abs(mean(cleanPlane(inkMask))-mean(cleanPlane(paperMask)));
noiseOnPaper = noisyPlane(paperMask)-cleanPlane(paperMask);
noiseOnPaper = noiseOnPaper-median(noiseOnPaper);
sorted = sort(abs(noiseOnPaper));
kept = sorted(1:max(1,floor(0.99*numel(sorted))));
noise = max(std(kept),1/sqrt(12));
cnr = contrast/noise;
end

function [scan,clean,inkMask,options] = pqMakeSyntheticScan(options)
% pqMakeSyntheticScan Synthetic scan of a printed target with known truth
%
%   [scan,clean,inkMask] = pqMakeSyntheticScan(options)
%       scan    - uint8 HxWx3 scan, with noise, shading and dust
%       clean   - double HxWx3 of the same scan with no noise or dust
%       inkMask - true where the target is printed
%
%   Having clean alongside scan is what makes the comparison objective: the
%   real contrast of any channel or combination can be measured from clean
%   over inkMask, and the real noise from the difference between the two
%   over the paper, so every selection can be scored against what was
%   actually there.
%
%   options fields, all optional:
%       seed        - random seed
%       imageSize   - [rows columns], default [512 640]
%       paperLevel  - 1x3 paper code value per channel, default [246 245 240]
%       inkDensity  - 1x3 fraction of paper absorbed by the ink in each
%                     channel, e.g. [0.75 0.25 0.05] for cyan
%       noise       - 1x3 noise standard deviation per channel
%       noiseShared - noise standard deviation common to all channels, which
%                     is what a scanner illumination or gain wobble looks
%                     like, and what makes a channel mix worthwhile
%       feature     - 'bars', 'patch', 'fineLines' or 'text'
%       tint        - 0 to 1, ink coverage inside the feature; below 1 the
%                     feature is halftone screened
%       screenPeriod- halftone screen period in pixels
%       gradient    - peak to peak illumination shading, code values
%       dustCount   - number of dust specks
%       brightFeature - true to make the feature lighter than paper
defaults = struct('seed',1,'imageSize',[512 640], ...
    'paperLevel',[246 245 240],'inkDensity',[0.7 0.7 0.68], ...
    'noise',[2 2 2],'noiseShared',0,'feature','bars','tint',1, ...
    'screenPeriod',6,'gradient',0,'dustCount',0,'brightFeature',false);
if(nargin < 1)
    options = struct();
end
for field = fieldnames(defaults)'
    if(~isfield(options,field{1}))
        options.(field{1}) = defaults.(field{1});
    end
end

pqSeedRandom(options.seed);
numberRows = options.imageSize(1);
numberColumns = options.imageSize(2);
[columnGrid,rowGrid] = meshgrid(1:numberColumns,1:numberRows);

% Printed feature geometry
inkMask = false(numberRows,numberColumns);
switch(lower(options.feature))
    case 'bars'
        barPeriod = 40;
        inMiddle = rowGrid > 0.15*numberRows & rowGrid < 0.85*numberRows;
        inkMask = inMiddle & mod(columnGrid,barPeriod) < barPeriod/2;
    case 'patch'
        inkMask = rowGrid > 0.3*numberRows & rowGrid < 0.75*numberRows ...
            & columnGrid > 0.2*numberColumns & columnGrid < 0.8*numberColumns;
    case 'finelines'
        for line = 1:6
            row = round(line*numberRows/7);
            inkMask(row:row+1,round(0.1*numberColumns):round(0.9*numberColumns)) = true;
        end
        for line = 1:6
            column = round(line*numberColumns/7);
            inkMask(round(0.1*numberRows):round(0.9*numberRows),column:column+1) = true;
        end
    case 'text'
        for block = 1:120
            row = 1+floor(rand*(numberRows-14));
            column = 1+floor(rand*(numberColumns-10));
            inkMask(row:row+8+floor(rand*4),column:column+2+floor(rand*4)) = true;
        end
    otherwise
        error('pqMakeSyntheticScan: unknown feature %s',options.feature);
end

% Halftone screening inside the feature
if(options.tint >= 1)
    coverage = double(inkMask);
else
    angle = pi/4;
    screenRow = rowGrid*cos(angle)+columnGrid*sin(angle);
    screenColumn = -rowGrid*sin(angle)+columnGrid*cos(angle);
    screen = 0.5+0.5*sin(2*pi*screenRow/options.screenPeriod) ...
        .*sin(2*pi*screenColumn/options.screenPeriod);
    coverage = double(inkMask & screen < options.tint);
end

% The true printed area is where ink actually lands, which for a screened
% tint is the dots and not the whole patch
inkMask = coverage > 0;

% Ink laid on paper, then illumination shading over the whole scan
clean = zeros(numberRows,numberColumns,3);
for channel = 1:3
    if(options.brightFeature)
        level = options.paperLevel(channel) ...
            *(1+options.inkDensity(channel)*coverage);
    else
        level = options.paperLevel(channel) ...
            *(1-options.inkDensity(channel)*coverage);
    end
    shading = 1+options.gradient/options.paperLevel(channel) ...
        *(columnGrid/numberColumns-0.5);
    clean(:,:,channel) = level.*shading;
end

% Noise, both per channel and common to all channels
scan = clean;
sharedNoise = options.noiseShared*randn(numberRows,numberColumns);
for channel = 1:3
    scan(:,:,channel) = scan(:,:,channel) ...
        +options.noise(channel)*randn(numberRows,numberColumns)+sharedNoise;
end

% Dust sits on the scanner glass, so it darkens every channel at once
for speck = 1:options.dustCount
    row = 2+floor(rand*(numberRows-4));
    column = 2+floor(rand*(numberColumns-4));
    darkness = 60+rand*150;
    scan(row:row+1,column:column+1,:) = ...
        max(0,scan(row:row+1,column:column+1,:)-darkness);
end

scan = uint8(min(255,max(0,round(scan))));
clean = min(255,max(0,clean));
end

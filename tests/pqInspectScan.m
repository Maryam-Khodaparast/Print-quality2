function info = pqInspectScan(scan,outputFolder)
% pqInspectScan Report how a real scan scores, channel by channel
%
%   pqInspectScan(scan) takes an image array, the path of an image file, or
%   the path of a folder of image files, and prints for every channel and
%   every combination
%       contrast - how far the print sits from the paper
%       noise    - the noise of that channel, robust to the print itself
%       CNR      - contrast/noise, the score the selection is made on
%       std      - the standard deviation the old selection used, for
%                  comparison
%   followed by what each of the two selections picks. Where they disagree,
%   the CNR column says which one is right.
%
%   pqInspectScan(scan,outputFolder) also writes the chosen channel and its
%   printed area mask into that folder, so the choice can be looked at.
%
%   This is the one to run on your own scans. It needs no ground truth: the
%   numbers come from the scans themselves.
here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));
if(nargin < 2)
    outputFolder = '';
end

if(ischar(scan) && exist(scan,'dir'))
    files = pqImageFiles(scan);
    if(isempty(files))
        fprintf('No image files found in %s\n',scan);
        info = [];
        return
    end
    info = cell(1,numel(files));
    for file = 1:numel(files)
        info{file} = pqInspectScan(files{file},outputFolder);
    end
    return
end

name = 'scan';
if(ischar(scan))
    name = scan;
    scan = imread(scan);
end
fprintf('\n%s: %dx%dx%d %s\n',name,size(scan,1),size(scan,2),size(scan,3), ...
    class(scan));

[~,info] = findChannel2Use(scan);
[~,legacyInfo] = pqLegacyFindChannel2Use(scan);

fprintf('  %-32s %9s %9s %8s %9s\n','candidate','contrast','noise','CNR','std');
for candidate = 1:numel(info.candidates)
    stats = info.candidates(candidate).stats;
    standardDeviation = NaN;
    if(candidate <= numel(legacyInfo.standardDeviations))
        standardDeviation = legacyInfo.standardDeviations(candidate);
    end
    fprintf('  %-32s %9.1f %9.2f %8.1f %9.1f\n', ...
        info.candidates(candidate).name,stats.contrast,stats.sigma, ...
        stats.cnr,standardDeviation);
end
fprintf('  printed area found: %.2f%% of the scan, ink is %s than paper\n', ...
    100*info.inkFraction,pqSide(info.inkIsDark));
fprintf('  contrast to noise picks : %s (CNR %.1f)\n',info.method,info.cnr);
fprintf('  standard deviation picks: %s\n',legacyInfo.method);
if(info.lowConfidence)
    fprintf('  WARNING: nothing on this scan stands clear of its noise\n');
end
if(~strcmp(info.method,legacyInfo.method))
    fprintf('  the two disagree on this scan\n');
end

if(~isempty(outputFolder))
    if(~exist(outputFolder,'dir'))
        mkdir(outputFolder);
    end
    [~,stem] = fileparts(name);
    [greyscale,mask] = selectChannel(scan);
    imwrite(uint8(greyscale),fullfile(outputFolder,[stem '_selected.png']));
    imwrite(mask,fullfile(outputFolder,[stem '_mask.png']));
    fprintf('  written to %s\n',outputFolder);
end
end

function side = pqSide(inkIsDark)
if(inkIsDark)
    side = 'darker';
else
    side = 'lighter';
end
end

function files = pqImageFiles(folder)
patterns = {'*.tif','*.tiff','*.png','*.bmp','*.jpg','*.jpeg'};
files = {};
for pattern = 1:numel(patterns)
    found = dir(fullfile(folder,patterns{pattern}));
    for file = 1:numel(found)
        files{end+1} = fullfile(folder,found(file).name); %#ok<AGROW>
    end
end
end

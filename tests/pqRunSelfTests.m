function pqRunSelfTests()
% pqRunSelfTests Checks on the awkward inputs, run with no arguments
here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));
passed = 0;
failed = 0;

% A scan that behaves, on every integer class and on doubles
[scan,~,inkMask] = pqMakeSyntheticScan(struct('feature','bars','seed',7));
[image8,info] = findChannel2Use(scan);
[passed,failed] = pqCheck(passed,failed,'returns the input class', ...
    isa(image8,'uint8'));
[passed,failed] = pqCheck(passed,failed,'returns a single plane', ...
    size(image8,3) == 1 && isequal(size(image8),size(scan(:,:,1))));
[passed,failed] = pqCheck(passed,failed,'reports what it chose', ...
    ischar(info.method) && ~info.lowConfidence);
[~,info16] = findChannel2Use(uint16(double(scan)*257));
[passed,failed] = pqCheck(passed,failed,'handles uint16', ...
    abs(info16.cnr-info.cnr)/info.cnr < 0.15);
[~,infoDouble] = findChannel2Use(double(scan));
[passed,failed] = pqCheck(passed,failed,'handles double', ...
    abs(infoDouble.cnr-info.cnr)/info.cnr < 0.05);

% One channel only, which is what a greyscale scan gives
[greyOut,greyInfo] = findChannel2Use(scan(:,:,2));
[passed,failed] = pqCheck(passed,failed,'handles a single channel scan', ...
    isequal(greyOut,scan(:,:,2)) && greyInfo.sep2Use == 1);

% Blank and constant scans must not throw, and must say they are unsure
blank = uint8(200*ones(64,64,3));
[~,blankInfo] = findChannel2Use(blank);
[passed,failed] = pqCheck(passed,failed,'flat scan is low confidence', ...
    blankInfo.lowConfidence);
noiseOnly = uint8(min(255,max(0,200+8*randn(200,200,3))));
[~,noiseInfo] = findChannel2Use(noiseOnly);
[passed,failed] = pqCheck(passed,failed,'noise only is low confidence', ...
    noiseInfo.lowConfidence);

% Selection has to survive a scan that is mostly ink
[dense,~,denseInk] = pqMakeSyntheticScan(struct('feature','patch', ...
    'inkDensity',[0.6 0.6 0.6],'seed',3));
[~,mask] = selectChannel(dense);
[passed,failed] = pqCheck(passed,failed,'finds a solid patch', ...
    pqOverlap(mask,denseInk) > 0.9);

% A feature lighter than the paper comes back dark, with the paper level
% still on the paper
[bright,~,brightInk] = pqMakeSyntheticScan(struct('brightFeature',true, ...
    'inkDensity',[0.06 0.06 0.06],'feature','patch','seed',5));
[greyscale,brightMask,paper] = selectChannel(bright);
[passed,failed] = pqCheck(passed,failed,'inverts a bright feature', ...
    mean(greyscale(brightMask)) < paper);
[passed,failed] = pqCheck(passed,failed,'finds a bright feature', ...
    pqOverlap(brightMask,brightInk) > 0.8);

% The mask and the paper value of an ordinary scan
[~,barMask,barPaper] = selectChannel(scan);
[passed,failed] = pqCheck(passed,failed,'masks the print', ...
    pqOverlap(barMask,inkMask) > 0.95);
[passed,failed] = pqCheck(passed,failed,'measures the paper', ...
    abs(barPaper-246) < 3);

% A scan with no print at all has to raise, not return a mask of noise
try
    selectChannel(noiseOnly);
    [passed,failed] = pqCheck(passed,failed,'refuses a scan with no print',false);
catch err
    [passed,failed] = pqCheck(passed,failed,'refuses a scan with no print', ...
        ~isempty(strfind(err.message,'MASK')));
end

% Bad input
try
    findChannel2Use('not an image');
    [passed,failed] = pqCheck(passed,failed,'refuses a non image',false);
catch
    [passed,failed] = pqCheck(passed,failed,'refuses a non image',true);
end

% Time on a full size scan
big = pqMakeSyntheticScan(struct('imageSize',[2000 3000],'feature','text', ...
    'seed',2));
started = tic;
findChannel2Use(big);
elapsed = toc(started);
fprintf('  timing: 2000x3000x3 scan selected in %.2f s\n',elapsed);

fprintf('\n%d passed, %d failed\n\n',passed,failed);
if(failed > 0)
    error('pqRunSelfTests: %d checks failed',failed);
end
end

function [passed,failed] = pqCheck(passed,failed,name,condition)
if(condition)
    passed = passed+1;
    fprintf('  ok    %s\n',name);
else
    failed = failed+1;
    fprintf('  FAIL  %s\n',name);
end
end

function overlap = pqOverlap(mask,truth)
overlap = sum(sum(mask & truth))/max(sum(sum(mask | truth)),1);
end

function results = runHeadSeparation(action,varargin)
% runHeadSeparation Make the charts, or measure the scans
%
%   runHeadSeparation('bitmap',folder)
%       Writes the chart for every head join to folder: one image of the
%       whole chart, and one per physical head showing what that head is to
%       print. It will refuse while the head routing is unconfirmed - see
%       pqHeadJoins and pqHeadSeparationChart.
%
%   results = runHeadSeparation('measure',folder)
%       Reads every image in folder, works out which band it is, and reports
%       the signed displacement, the uncertainty and the verdict for each.
%
%   results = runHeadSeparation('demo')
%       Prints, scans and measures a band without a printer or a scanner, so
%       the whole path can be run and stepped through before any ink is used.
%
%   Everything it prints is signed. A head to the left of where it should be
%   reads negative here and stays negative.
if(nargin < 1)
    action = 'demo';
end
switch(lower(action))
    case 'bitmap'
        results = pqWriteBitmaps(varargin{:});
    case 'measure'
        results = pqMeasureFolder(varargin{:});
    case 'demo'
        results = pqDemo(varargin{:});
    otherwise
        error('PrintQuality:runHeadSeparation:unknownAction', ...
            'Use bitmap, measure or demo');
end
end

function results = pqWriteBitmaps(folder,joins,options)
if(nargin < 2 || isempty(joins))
    joins = pqHeadJoins();
end
if(nargin < 3)
    options = struct;
end
chart = pqHeadSeparationChart(joins,options);
[bitmap,byHead] = pqHeadSeparationBitmap(chart,options);
if(~exist(folder,'dir'))
    mkdir(folder);
end
imwrite(~bitmap,fullfile(folder,'chart.png'));
for k = 1:numel(byHead)
    imwrite(~byHead(k).bitmap, ...
        fullfile(folder,sprintf('chart-head-%d.png',byHead(k).head)));
end
results = chart;
fprintf('Wrote a %d by %d chart for %d joins to %s\n', ...
    chart.size(2),chart.size(1),numel(joins),folder);
if(~chart.routingVerified)
    fprintf(['This chart is marked NOT FOR PRODUCTION: the head routing ' ...
        'has not been confirmed.\n']);
end
end

function results = pqMeasureFolder(folder,joins)
if(nargin < 2 || isempty(joins))
    joins = pqHeadJoins();
end
files = dir(fullfile(folder,'*'));
files = files(~[files.isdir]);
patterns = {};
labels = {};
for k = 1:numel(joins)
    patterns{end+1} = pqSplitXPattern(joins(k));          %#ok<AGROW>
    labels{end+1} = sprintf('%s Split-X',joins(k).joinName); %#ok<AGROW>
    patterns{end+1} = pqMultiMarkPattern(joins(k));        %#ok<AGROW>
    labels{end+1} = sprintf('%s MultiMark',joins(k).joinName); %#ok<AGROW>
end
results = struct('file',{},'band',{},'separationMicrons',{}, ...
    'uncertaintyMicrons',{},'valid',{},'reasons',{});
fprintf('\n%-28s %-18s %10s %10s %8s  %s\n','file','band','microns', ...
    'plus minus','valid','reasons');
for k = 1:numel(files)
    name = fullfile(folder,files(k).name);
    try
        scan = imread(name);
    catch
        continue
    end
    [result,which] = pqBestBand(scan,patterns);
    if(isempty(which))
        fprintf('%-28s %-18s %10s\n',files(k).name,'(no band found)','');
        continue
    end
    results(end+1) = struct('file',files(k).name,'band',labels{which}, ...
        'separationMicrons',result.separationMicrons, ...
        'uncertaintyMicrons',result.uncertaintyMicrons, ...
        'valid',result.valid,'reasons',{result.reasons}); %#ok<AGROW>
    fprintf('%-28s %-18s %+10.2f %10.2f %8d  %s\n',files(k).name, ...
        labels{which},result.separationMicrons,result.uncertaintyMicrons, ...
        result.valid,strjoin(result.reasons,', '));
end
end

function [best,which] = pqBestBand(scan,patterns)
% Which band this scan holds, by how well each nominal pattern registers on
% it. A scan that matches nothing is reported as nothing rather than measured
% against the first pattern in the list.
best = [];
which = [];
quality = 0.25;
prepared = pqPrepareScan(scan);
for k = 1:numel(patterns)
    if(any(size(prepared.grey) < patterns{k}.size))
        continue
    end
    [~,score] = pqRegisterPattern(prepared.grey,prepared.paper,patterns{k});
    if(score > quality)
        quality = score;
        which = k;
    end
end
if(~isempty(which))
    best = measureHeadSeparation(scan,patterns{which});
end
end

function results = pqDemo(displacementMicrons)
if(nargin < 1)
    displacementMicrons = -50;
end
addpath(fullfile(fileparts(mfilename('fullpath')),'tests'));
joins = pqHeadJoins();
join = joins(1);
fprintf(['Join %s: head %d prints the upper arms, head %d the lower ones. ' ...
    'Routing verified: %d\n'],join.joinName,join.headA,join.headB, ...
    join.routingVerified);
results = struct('band',{},'result',{});
for make = {@pqSplitXPattern,@pqMultiMarkPattern}
    pattern = make{1}(join);
    scan = pqSimulateHeadSeparation(pattern, ...
        struct('displacementMicrons',displacementMicrons,'seed',1));
    result = measureHeadSeparation(scan,pattern);
    results(end+1) = struct('band',pattern.name,'result',result); %#ok<AGROW>
    fprintf('%-14s printed %+7.2f um, measured %+7.2f +- %.2f um, valid %d  %s\n', ...
        pattern.name,displacementMicrons,result.separationMicrons, ...
        result.uncertaintyMicrons,result.valid,strjoin(result.reasons,', '));
end
fprintf(['Both bands are refused above because this join has not had its ' ...
    'head routing confirmed, which is the point of that flag.\n']);
end

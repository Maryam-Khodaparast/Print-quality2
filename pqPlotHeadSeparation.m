function figures = pqPlotHeadSeparation(scan,pattern,result,options)
% pqPlotHeadSeparation Debug figures for one head separation band
%
%   pqPlotHeadSeparation(scan,pattern,result) draws what the analyser did:
%   the nominal position of each arm, the centre it found in each row, the
%   rows it threw away, the fitted arm lines, the virtual centres they cross
%   at, and the ink witness profiles.
%
%   Nothing in the analysis calls this. It opens windows, and an analyser
%   that opens windows on a production line is a nuisance at best. Call it
%   when a band has been refused and the reason needs looking at.
%
%   options.groups   which measurement groups to draw, default the first
%   options.save     folder to write the figures to instead of showing them
if(nargin < 4)
    options = struct;
end
if(~isfield(options,'groups'))
    options.groups = 1;
end
if(~isfield(options,'save'))
    options.save = '';
end
%   The drawing is separate from the reading: pqHeadSeparationOverlay works
%   out what to draw and is covered by the self tests, so a renamed field is
%   caught there rather than the first time somebody needs a figure.
figures = [];
if(~isfield(result,'arms') || isempty(result.arms))
    warning('PrintQuality:pqPlotHeadSeparation:nothingMeasured', ...
        'This result has no arm measurements to draw (%s)', ...
        strjoin(result.reasons,', '));
    return
end
offset = result.registration.offset;
prepared = pqPrepareScan(scan);
grey = prepared.grey;

for group = options.groups(:)'
    overlay = pqHeadSeparationOverlay(pattern,result,group);
    if(~overlay.found)
        continue
    end
    rowRange = max(1,overlay.rows(1)):min(size(grey,1),overlay.rows(2));
    columnRange = max(1,overlay.columns(1)):min(size(grey,2),overlay.columns(2));
    figures(end+1) = figure('Name',sprintf('%s group %d', ...
        pattern.joinName,group)); %#ok<AGROW>
    imagesc(columnRange,rowRange,grey(rowRange,columnRange));
    colormap(gray); axis image; hold on
    for arm = overlay.arms
        colour = 'r';
        if(arm.owner == 2)
            colour = 'c';
        end
        plot(arm.nominal,arm.rows,[colour ':'])
        plot(arm.centre,arm.rows,[colour '.'],'MarkerSize',4)
        plot(arm.droppedCentre,arm.droppedRows,'yx','MarkerSize',6)
    end
    for k = 1:size(overlay.centres,1)
        if(all(isfinite(overlay.centres(k,:))))
            plot(overlay.centres(k,1),overlay.centres(k,2),'g+', ...
                'MarkerSize',14,'LineWidth',2)
        end
    end
    title(overlay.title)
    hold off
end

figures(end+1) = pqPlotWitness(grey,pattern,result,offset);
if(~isempty(options.save))
    for k = 1:numel(figures)
        print(figures(k),fullfile(options.save, ...
            sprintf('%s-%d.png',pattern.joinName,k)),'-dpng')
    end
end
end

function handle = pqPlotWitness(grey,pattern,result,offset)
handle = figure('Name',sprintf('%s ink witness',pattern.joinName));
colours = {'r','c'};
for owner = 1:2
    features = pattern.witness([pattern.witness.owner] == owner);
    lines = features(strcmp({features.kind},'line'));
    for k = 1:numel(lines)
        feature = lines(k);
        columns = round(mean(feature.columns+offset(2)))+(-12:12);
        rows = feature.rows+offset(1);
        columns = columns(columns >= 1 & columns <= size(grey,2));
        rows = rows(rows >= 1 & rows <= size(grey,1));
        plot(columns-mean(columns), ...
            result.scan.paper-mean(grey(rows,columns),1),colours{owner});
        hold on
    end
end
grid on
xlabel('pixels from the centre of the feature')
ylabel('ink above paper, code values')
title(sprintf(['%s ink witness: growth %.3f and %.3f px, difference %.3f\n' ...
    'that difference could be moving the answer by up to %.2f um'], ...
    pattern.joinName,result.inkGain(1).growth,result.inkGain(2).growth, ...
    result.growthDifferencePixels,result.inkBiasBoundMicrons))
hold off
end

function overlay = pqHeadSeparationOverlay(pattern,result,group)
% pqHeadSeparationOverlay What a debug figure of one group has to draw
%
%   overlay = pqHeadSeparationOverlay(pattern,result,group) collects
%   everything pqPlotHeadSeparation draws for one measurement group: the rows
%   and columns to show, each arm's measured centres, the rows it dropped,
%   the fitted line, and the virtual centres.
%
%   It is separate from the drawing so that it can be tested. Figures need a
%   screen, or at least a working text renderer, and a debug figure that
%   nobody can run until the day they need it is worth very little. Reading
%   the result is where the mistakes are - a renamed field, an arm index that
%   no longer means what it did - and that part runs anywhere.
overlay = struct('found',false,'rows',[],'columns',[],'arms',[], ...
    'centres',[],'separationMicrons',NaN,'title','');
chosen = find(strcmp({pattern.measurements.kind},'measure') ...
    & [pattern.measurements.group] == group);
if(isempty(chosen) || ~isfield(result,'arms') || isempty(result.arms))
    return
end
measurement = pattern.measurements(chosen(1));
marks = pattern.marks([measurement.outer measurement.middle]);
offset = result.registration.offset;

span = pattern.options.halfGap+pattern.options.armColumns;
overlay.rows = [min([marks.apexRow])+offset(1)-span ...
    max([marks.apexRow])+offset(1)+span];
overlay.columns = [marks(1).apexColumn+offset(2)-span ...
    marks(1).apexColumn+offset(2)+span];

arms = struct('owner',{},'rows',{},'nominal',{},'centre',{},'kept',{}, ...
    'droppedRows',{},'droppedCentre',{},'line',{});
for mark = marks
    for k = mark.arms
        arm = result.arms(k);
        measured = arm.measured;
        kept = measured.valid;
        dropped = ~kept & isfinite(measured.centre);
        arms(end+1) = struct('owner',arm.owner, ...
            'rows',measured.rows(kept),'nominal',measured.nominal(kept)+offset(2), ...
            'centre',measured.centre(kept),'kept',sum(kept), ...
            'droppedRows',measured.rows(dropped), ...
            'droppedCentre',measured.centre(dropped), ...
            'line',arm.fit.slope*(measured.rows-arm.fit.yReference) ...
            +arm.fit.intercept); %#ok<AGROW>
    end
end
overlay.arms = arms;
overlay.centres = [result.groups(chosen(1)).apexOuter; ...
    result.groups(chosen(1)).apexMiddle];
overlay.separationMicrons = result.groups(chosen(1)).separationPixels ...
    *pattern.micronsPerPixel;
if(result.valid)
    verdict = 'accepted';
else
    verdict = ['REFUSED: ' strjoin(result.reasons,', ')];
end
overlay.title = sprintf(['%s group %d: %+.2f um   band %+.2f +- %.2f um   %s' ...
    '\nred head %d, cyan head %d, yellow x rows dropped, green + virtual centres'], ...
    pattern.joinName,group,overlay.separationMicrons, ...
    result.separationMicrons,result.uncertaintyMicrons,verdict, ...
    pattern.headA,pattern.headB);
overlay.found = true;
end

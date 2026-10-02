function [bitmap,byHead] = pqHeadSeparationBitmap(chart,options)
% pqHeadSeparationBitmap The bitmaps to send to each head
%
%   [bitmap,byHead] = pqHeadSeparationBitmap(chart) returns the whole chart
%   as one bitmap, and a map from physical head number to the bitmap that
%   head is to print. byHead is what the printer actually needs: a chart
%   whose two heads are swapped looks identical as one bitmap and measures
%   the wrong thing.
%
%   A chart whose routing has not been confirmed is refused. Pass
%   options.allowUnverified to get it anyway for development, in which case
%   byHead is still returned but the chart is marked as not for production
%   and a warning goes to the debug log. Never print an unverified chart and
%   adjust a machine from what it says.
if(nargin < 2)
    options = struct;
end
if(~isfield(options,'allowUnverified'))
    options.allowUnverified = false;
end
if(~chart.routingVerified)
    if(~options.allowUnverified)
        error('PrintQuality:pqHeadSeparationBitmap:routingNotVerified', ...
            ['Head to head routing has not been confirmed for this chart. ' ...
            'The chart composition code has to set routingVerified on each ' ...
            'join, after checking which physical head prints each column of ' ...
            'the shared region. Pass allowUnverified only for development.']);
    end
    writeToDebugLog(['Head separation chart built with UNVERIFIED routing, ' ...
        'not for production use'],'warning')
end

bitmap = pqRasteriseRects(chart.rects,chart.size) > 0.5;
byHead = struct('head',{},'bitmap',{});
for head = chart.heads(:)'
    byHead(end+1) = struct('head',head, ...
        'bitmap',pqRasteriseRects(chart.rects(chart.headOfRect == head,:), ...
        chart.size) > 0.5); %#ok<AGROW>
end
end

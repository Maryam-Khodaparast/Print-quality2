function chart = pqHeadSeparationChart(joins,options)
% pqHeadSeparationChart One chart covering every head to head join
%
%   chart = pqHeadSeparationChart(joins) lays a Split-X band and a MultiMark
%   band for each join into a single image, and records which physical head
%   prints every rectangle in it.
%
%   The ownership is the point of this function. A band's geometry says that
%   some ink belongs to the head printing the upper arms and some to the head
%   printing the lower ones; it does not and cannot say which physical head
%   that is. Getting it the wrong way round gives a chart that looks right,
%   analyses cleanly and reports the displacement with the sign reversed, or
%   measures a head against itself and reports zero. Nothing downstream can
%   catch that, so it is caught here:
%
%   * chart.headOfRect names a physical head for every rectangle, taken from
%     joins(k).headA and joins(k).headB rather than assumed;
%   * chart.routingVerified is the AND of the joins' own flags, and
%     pqHeadSeparationBitmap will not write a production bitmap while it is
%     false. pqHeadJoins cannot set it - only the code that actually routes
%     nozzles to heads knows, and it has to say so.
%
%   chart = pqHeadSeparationChart(joins,options) takes:
%     splitX      options passed to pqSplitXPattern
%     multiMark   options passed to pqMultiMarkPattern, or [] to leave the
%                 cross check band out
%     clearRows   blank rows between bands
if(nargin < 1 || isempty(joins))
    joins = pqHeadJoins();
end
if(nargin < 2)
    options = struct;
end
if(~isfield(options,'splitX'))
    options.splitX = struct;
end
if(~isfield(options,'multiMark'))
    options.multiMark = struct;
end
if(~isfield(options,'clearRows'))
    options.clearRows = 48;
end

chart = struct('bands',[],'size',[0 0],'rects',zeros(0,4), ...
    'headOfRect',zeros(0,1),'heads',[],'routingVerified',true, ...
    'micronsPerPixel',25400/720);
bands = struct('pattern',{},'kind',{},'joinName',{},'origin',{});
top = options.clearRows;
width = 0;
for k = 1:numel(joins)
    join = joins(k);
    chart.routingVerified = chart.routingVerified && join.routingVerified;
    made = {pqSplitXPattern(join,options.splitX)};
    kinds = {'splitx'};
    if(~isempty(options.multiMark))
        made{end+1} = pqMultiMarkPattern(join,options.multiMark); %#ok<AGROW>
        kinds{end+1} = 'multimark';                               %#ok<AGROW>
    end
    for b = 1:numel(made)
        bands(end+1) = struct('pattern',made{b},'kind',kinds{b}, ...
            'joinName',join.joinName,'origin',[top options.clearRows]); %#ok<AGROW>
        top = top+made{b}.size(1)+options.clearRows;
        width = max(width,made{b}.size(2)+2*options.clearRows);
    end
end
chart.bands = bands;
chart.size = [top width];
chart.heads = unique([[joins.headA] [joins.headB]]);

% Rectangles of the whole chart, each one carrying the physical head that
% prints it rather than the band's local idea of A and B.
for k = 1:numel(bands)
    pattern = bands(k).pattern;
    origin = bands(k).origin;
    rects = pattern.rects;
    rects(:,1:2) = rects(:,1:2)+origin(1)-1;
    rects(:,3:4) = rects(:,3:4)+origin(2)-1;
    heads = zeros(size(pattern.rectOwner));
    heads(pattern.rectOwner == 1) = pattern.headA;
    heads(pattern.rectOwner == 2) = pattern.headB;
    chart.rects = [chart.rects; rects];
    chart.headOfRect = [chart.headOfRect; heads];
end
end

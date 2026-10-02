function joins = pqHeadJoins(options)
% pqHeadJoins The head to head joins a separation chart has to measure
%
%   joins = pqHeadJoins() returns one entry per adjacent pair of printheads,
%   in the order the chart lays them out. Every entry carries the two head
%   numbers, the cross web nozzle columns the two heads are believed to
%   share, and a routingVerified flag.
%
%   routingVerified is false in this file and nothing here can set it true.
%   The flag exists because the one thing a printed chart cannot tell you is
%   which physical head put the ink on the paper: a band that looks perfect
%   while the ownership is swapped measures the wrong quantity and still
%   reports a confident number. Only the code that composes the chart and
%   routes nozzles knows the answer, so that code has to fill this in, and
%   pqHeadSeparationChart refuses to emit a production bitmap until it has.
%
%   The layout below is the five head GS3-2000 stagger with three heads in
%   the back row and two in front of them, printing 1-3-5 towards 2-4. It is
%   written down so it can be checked and corrected, not because it is
%   known to be right.
%
%   joins(k).joinName        - text, for figures and reports
%   joins(k).headA           - head printing the upper arms of each group
%   joins(k).headB           - head printing the lower arms of each group
%   joins(k).columnRange     - [first last] shared nozzle, head A numbering
%   joins(k).routingVerified - false until the chart composer confirms it
%   joins(k).notes           - what still has to be checked
if(nargin < 1)
    options = struct;
end
if(~isfield(options,'headRowOne'))
    % Back row, in cross web order.
    options.headRowOne = [1 3 5];
end
if(~isfield(options,'headRowTwo'))
    % Front row, in cross web order, sitting between the back row heads.
    options.headRowTwo = [2 4];
end
if(~isfield(options,'overlapColumns'))
    % Shared nozzle columns at a join. A guess until measured on the
    % machine: it sets how wide the printed band can be and therefore how
    % many nozzles each measurement averages over.
    options.overlapColumns = 128;
end

order = pqInterleaveRows(options.headRowOne,options.headRowTwo);
joins = struct('joinName',{},'headA',{},'headB',{},'columnRange',{}, ...
    'routingVerified',{},'notes',{});
for k = 1:numel(order)-1
    headA = order(k);
    headB = order(k+1);
    joins(k).joinName = sprintf('%d-%d',headA,headB);
    joins(k).headA = headA;
    joins(k).headB = headB;
    joins(k).columnRange = [1 options.overlapColumns];
    joins(k).routingVerified = false;
    joins(k).notes = ['Confirm which head owns each column of the band, ' ...
        'and that headA is the one printing the upper arms'];
end
end

function order = pqInterleaveRows(rowOne,rowTwo)
% Cross web order of the heads, taking one from each row in turn. The two
% rows are at different down web positions, so neighbours in this order are
% the pairs whose swathes meet on the paper.
order = zeros(1,numel(rowOne)+numel(rowTwo));
order(1:2:end) = rowOne;
order(2:2:end) = rowTwo;
end

function result = measureHeadSeparation(scan,pattern,options)
% measureHeadSeparation Read a head separation band off a scan
%
%   result = measureHeadSeparation(scan,pattern) sends the scan to the
%   analyser that belongs to the pattern it was printed from, and returns the
%   signed cross web displacement of head B relative to head A in microns,
%   with an uncertainty and a verdict.
%
%   result.separationMicrons is signed throughout. A head to the left of
%   where it should be reads negative and stays negative: nothing in this
%   code takes an absolute value, folds a result onto a pattern pitch or
%   turns a result round because it looked wrong.
%
%   result.valid is false when any check failed, and result.reasons says
%   which. A false here is not a failure of the printer - it means the scan
%   cannot answer the question, and adjusting a head from a number that came
%   with reasons attached is how a machine ends up further out than it
%   started.
if(nargin < 3)
    options = struct;
end
switch(pattern.name)
    case 'splitx-v3'
        result = pqAnalyseSplitX(scan,pattern,options);
    case 'multimark-v1'
        result = pqAnalyseMultiMark(scan,pattern,options);
    otherwise
        error('PrintQuality:measureHeadSeparation:unknownPattern', ...
            'No analyser for pattern %s',pattern.name);
end
result.patternName = pattern.name;
if(~pattern.routingVerified)
    % Say it every time. The measurement is of the ink that two sets of
    % nozzles put down; calling one of them head A is somebody else's claim
    % until it has been checked.
    result.reasons{end+1} = 'routingNotVerified';
    result.valid = false;
end
end

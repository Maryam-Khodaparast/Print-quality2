function conditions = pqHeadSeparationConditions(displacementMicrons)
% pqHeadSeparationConditions The stress cases a separation band has to face
%
%   conditions = pqHeadSeparationConditions(displacement) returns a named
%   list of simulation conditions, each with the same true head displacement
%   and one thing wrong with it.
%
%   Each entry carries inkOffsetPixels: how far the condition moves head B's
%   ink relative to head A's, on top of the head itself moving. Growing ink
%   by gLeft on the left and gRight on the right is the same as moving it by
%   (gRight-gLeft)/2 and then growing it evenly, and the moving part is what
%   a measurement of a printed image sees. Scoring against the head alone
%   would mark a correct reading of where the ink is as an error; scoring
%   against the ink alone would hide that the head is not where the ink says
%   it is. The benchmark reports both.
%
%   featureDependent marks the conditions where head B's ink does not even
%   move by one amount - it moves by different amounts on different features
%   - so there is no single right answer and the band should refuse.
if(nargin < 1)
    displacementMicrons = 50;
end
conditions = struct('name',{},'condition',{},'inkOffsetPixels',{}, ...
    'featureDependent',{});
base = struct('displacementMicrons',displacementMicrons);

conditions = add(conditions,'clean',base,0,false);
conditions = add(conditions,'missing head B',set(base,'missingHeadB',true),0,false);
conditions = add(conditions,'one dead edge nozzle', ...
    set(base,'deadNozzlesB',203),0,false);
conditions = add(conditions,'eight dead adjacent nozzles', ...
    set(base,'deadNozzlesB',203:210),0,false);
conditions = add(conditions,'ten percent of B nozzles dead', ...
    set(base,'deadNozzlesB',100+find(rand(1,800) < 0.10)),0,false);
conditions = add(conditions,'symmetric dot gain', ...
    set(set(base,'growthA',[0.8 0.8]),'growthB',[0.8 0.8]),0,false);
conditions = add(conditions,'extra symmetric gain on B', ...
    set(base,'growthB',[0.8 0.8]),0,false);
conditions = add(conditions,'one sided B growth +0.75', ...
    set(base,'growthB',[0 0.75]),0.375-0,false);
conditions = add(conditions,'one sided B growth -0.75', ...
    set(base,'growthB',[0.75 0]),-0.375,false);
conditions = add(conditions,'one sided B growth +0.4', ...
    set(base,'growthB',[0.2 0.6]),0.2,false);
conditions = add(conditions,'growth depends on feature width', ...
    set(base,'growthBWidthSlope',0.5),NaN,true);
conditions = add(conditions,'head B rotated 2 mrad', ...
    set(base,'headBRotation',0.002),0,false);
conditions = add(conditions,'scanner rotated 5 mrad', ...
    set(base,'scannerRotation',0.005),0,false);
conditions = add(conditions,'scanner x scale 2e-4', ...
    set(base,'scannerScaleError',2e-4),0,false);
conditions = add(conditions,'quadratic web distortion', ...
    set(base,'webDistortion',2.0),0,false);
conditions = add(conditions,'down web B displacement', ...
    set(base,'displacementYMicrons',60),0,false);
conditions = add(conditions,'heavy optical blur', ...
    set(base,'blurSigma',1.8),0,false);
conditions = add(conditions,'noisy scan', ...
    set(set(base,'readNoise',6),'paperVariation',5),0,false);
conditions = add(conditions,'faint print', ...
    set(base,'contrast',60),0,false);
conditions = add(conditions,'illumination shading', ...
    set(base,'paperVariation',12),0,false);
conditions = add(conditions,'combined stress', ...
    set(set(set(set(base,'deadNozzlesB',203:208),'scannerRotation',0.003), ...
    'readNoise',4),'growthA',[0.6 0.6]),0,false);
end

function conditions = add(conditions,name,condition,inkOffsetPixels,featureDependent)
conditions(end+1) = struct('name',name,'condition',condition, ...
    'inkOffsetPixels',inkOffsetPixels,'featureDependent',featureDependent);
end

function condition = set(condition,field,value)
condition.(field) = value;
end

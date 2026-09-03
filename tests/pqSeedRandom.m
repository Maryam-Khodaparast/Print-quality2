function pqSeedRandom(seed)
% pqSeedRandom Repeatable random numbers under both MATLAB and Octave
if(exist('rng','builtin') || exist('rng','file'))
    rng(seed);
else
    rand('state',seed); %#ok<RAND>
    randn('state',seed); %#ok<RAND>
end
end

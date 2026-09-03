function writeToDebugLog(message,level)
% writeToDebugLog Stub used when running the tests outside the main project
%
%   Set the global pqDebugLogVerbose to true to see the messages.
global pqDebugLogVerbose
global pqDebugLogMessages
if(isstruct(message) || isobject(message))
    if(isprop(message,'message') || isfield(message,'message'))
        message = message.message;
    else
        message = 'error object';
    end
end
pqDebugLogMessages{end+1} = sprintf('[%s] %s',level,message);
if(~isempty(pqDebugLogVerbose) && pqDebugLogVerbose)
    fprintf('[%s] %s\n',level,message);
end
end

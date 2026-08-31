function hash = computeFileSHA256(fileName)
%COMPUTEFILESHA256 Return the lowercase SHA-256 digest of one local file.

if ~(ischar(fileName) || (isstring(fileName) && isscalar(fileName))) || ...
        ~isfile(fileName)
    error('TrafoDNA:HashFileMissing', ...
        'A readable file is required for SHA-256 hashing.');
end
fileName = char(fileName);
[fileId,message] = fopen(fileName,'rb');
if fileId < 0
    error('TrafoDNA:HashFileOpenFailed', ...
        'Could not open "%s": %s',fileName,message);
end
cleanup = onCleanup(@() fclose(fileId));
try
    digest = javaMethod('getInstance','java.security.MessageDigest', ...
        'SHA-256');
    while ~feof(fileId)
        bytes = fread(fileId,1024*1024,'*uint8');
        if ~isempty(bytes)
            digest.update(typecast(bytes,'int8'));
        end
    end
    rawDigest = typecast(digest.digest(),'uint8');
catch exception
    error('TrafoDNA:SHA256Unavailable', ...
        'MATLAB could not compute SHA-256: %s',exception.message);
end
hash = lower(reshape(dec2hex(rawDigest,2).',1,[]));
clear cleanup
end

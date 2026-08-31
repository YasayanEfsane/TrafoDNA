function v32FinalReport = run_v32_final_report()
%RUN_V32_FINAL_REPORT Build evidence files from the locked V3.2 result.
%   This read-only reporting entry point never calls MAIN_V32_FINAL and
%   never modifies either locked MAT input.

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));
cfg = defaultV32Config();
requiredFiles = {cfg.runtime.preparedBundleFile; ...
    cfg.runtime.finalResultFile;cfg.runtime.finalLockFile};
roles = {'PreparedBundle';'LockedFinalResult';'FinalOpenedLock'};
for k = 1:numel(requiredFiles)
    if ~isfile(requiredFiles{k})
        error('TrafoDNA:MissingV32ReportInput', ...
            'Required locked evidence file is missing: %s',requiredFiles{k});
    end
end

loadedPreparation = load(cfg.runtime.preparedBundleFile,'preparedV32');
loadedFinal = load(cfg.runtime.finalResultFile,'finalV32');
if ~isfield(loadedPreparation,'preparedV32') || ...
        ~isfield(loadedFinal,'finalV32')
    error('TrafoDNA:InvalidV32ReportInput', ...
        'Locked MAT files do not contain the expected result structures.');
end
preparedV32 = loadedPreparation.preparedV32;
finalV32 = loadedFinal.finalV32;
if ~v32ProtocolContractsEquivalent(preparedV32.contract, ...
        buildV32ProtocolContract(cfg))
    error('TrafoDNA:V32ReportContractChanged', ...
        'Current result-relevant protocol differs from the prepared bundle.');
end

fileName = cell(size(requiredFiles));
bytes = zeros(size(requiredFiles));
sha256 = cell(size(requiredFiles));
for k = 1:numel(requiredFiles)
    fileInfo = dir(requiredFiles{k});
    fileName{k} = fileInfo.name;
    bytes(k) = fileInfo.bytes;
    sha256{k} = computeFileSHA256(requiredFiles{k});
end
evidenceManifest = table(roles,fileName,bytes,sha256, ...
    'VariableNames',{'Role','FileName','Bytes','SHA256'});

options.outputDirectory = cfg.runtime.reportDirectory;
options.figureVisible = cfg.runtime.figureVisible;
options.createFigures = true;
options.saveFiles = true;
options.verbose = true;
options.evidenceManifest = evidenceManifest;
v32FinalReport = createV32FinalReport(preparedV32,finalV32,options);
end

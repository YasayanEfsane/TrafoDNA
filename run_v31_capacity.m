%RUN_V31_CAPACITY Load the locked V3 result and run the V3.1 capacity audit.
projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));

if ~exist('activeResults','var')
    if exist('analysisResults','var') && isstruct(analysisResults) && ...
            isfield(analysisResults,'pufModel')
        activeResults = analysisResults;
    else
        resultFile = fullfile(projectRoot,'results_active_v3', ...
            'trafodna_active_v3_results.mat');
        if ~isfile(resultFile)
            error('TrafoDNA:MissingV3Result', ...
                ['The locked V3 MAT result was not found. Run ' ...
                 '"activeResults = main_active();" once before this audit.']);
        end
        loadedV3 = load(resultFile,'analysisResults');
        activeResults = loadedV3.analysisResults;
    end
end

capacityAudit = analyzeV31Capacity(activeResults); %#ok<NASGU>

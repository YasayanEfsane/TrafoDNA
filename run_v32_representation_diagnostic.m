%RUN_V32_REPRESENTATION_DIAGNOSTIC Diagnose the locked V3 bit representation.
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
                ['The locked V3 MAT result was not found. Copy the original ' ...
                 'trafodna_active_v3_results.mat into results_active_v3 or ' ...
                 'load it as activeResults before running this diagnostic.']);
        end
        loadedV3 = load(resultFile,'analysisResults');
        activeResults = loadedV3.analysisResults;
    end
end

representationDiagnostic = analyzeV32Representation(activeResults); %#ok<NASGU>

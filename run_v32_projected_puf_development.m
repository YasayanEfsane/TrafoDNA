%RUN_V32_PROJECTED_PUF_DEVELOPMENT Run final-excluding V3.2 development.
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
                 '"activeResults = main_active();" once, then rerun this ' ...
                 'development study.']);
        end
        loadedV3 = load(resultFile,'analysisResults');
        activeResults = loadedV3.analysisResults;
    end
end

projectedPUFStudy = analyzeV32ProjectedPUF(activeResults); %#ok<NASGU>

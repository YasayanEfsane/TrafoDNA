function aggregate = summarizeV33FinalAudit(finalCohorts,cfg)
%SUMMARIZEV33FINALAUDIT Apply the preregistered across-cohort decision rule.

if ~iscell(finalCohorts) || numel(finalCohorts) ~= cfg.v33.numCohorts || ...
        any(cellfun(@isempty,finalCohorts))
    error('TrafoDNA:IncompleteV33FinalAudit', ...
        'Every preregistered cohort must be evaluated before aggregation.');
end

numCohorts = cfg.v33.numCohorts;
cohort = zeros(numCohorts,1);
seed = zeros(numCohorts,1);
finalConditionIds = cell(numCohorts,1);
identityAccuracy = zeros(numCohorts,1);
identityEER = zeros(numCohorts,1);
pufReliability = zeros(numCohorts,1);
pufUniqueness = zeros(numCohorts,1);
eligibleBits = zeros(numCohorts,1);
worstScenarioReliability = zeros(numCohorts,1);
sessionIdentityAccuracy = zeros(numCohorts,1);
sessionIdentityEER = zeros(numCohorts,1);
sessionPUFReliability = zeros(numCohorts,1);
maximumSelectedCorrelation = zeros(numCohorts,1);
checksPassed = zeros(numCohorts,1);
cohortPassed = false(numCohorts,1);

for k = 1:numCohorts
    result = finalCohorts{k};
    required = {'index','seed','identityMetrics','pufMetrics', ...
        'worstConditionPUFReliability','sessionIdentityMetrics', ...
        'sessionPUFMetrics','maximumSelectedCorrelation','checks', ...
        'cohortPassed','integrity'};
    for fieldIndex = 1:numel(required)
        if ~isfield(result,required{fieldIndex})
            error('TrafoDNA:InvalidV33FinalCohort', ...
                'Final cohort %d is missing field "%s".', ...
                k,required{fieldIndex});
        end
    end
    if result.index ~= k || result.seed ~= cfg.v33.cohortSeeds(k) || ...
            ~isequal(result.integrity.finalConditionIds, ...
            cfg.v33.scenarioIdBases(k)+ ...
            cfg.v33.knownScenarioCount+ ...
            cfg.v33.developmentScenarioCount+ ...
            (1:cfg.v33.finalScenarioCount))
        error('TrafoDNA:V33FinalCohortOrderChanged', ...
            'Final cohort order, seed, or condition IDs changed.');
    end
    cohort(k) = result.index;
    seed(k) = result.seed;
    finalConditionIds{k} = mat2str(result.integrity.finalConditionIds);
    identityAccuracy(k) = result.identityMetrics.accuracy;
    identityEER(k) = result.identityMetrics.eer;
    pufReliability(k) = result.pufMetrics.reliability;
    pufUniqueness(k) = result.pufMetrics.uniqueness;
    eligibleBits(k) = result.pufMetrics.numSelectedEligibleBits;
    worstScenarioReliability(k) = ...
        result.worstConditionPUFReliability;
    sessionIdentityAccuracy(k) = ...
        result.sessionIdentityMetrics.accuracy;
    sessionIdentityEER(k) = result.sessionIdentityMetrics.eer;
    sessionPUFReliability(k) = result.sessionPUFMetrics.reliability;
    maximumSelectedCorrelation(k) = ...
        result.maximumSelectedCorrelation;
    checksPassed(k) = sum(result.checks.Passed);
    cohortPassed(k) = result.cohortPassed && ...
        checksPassed(k) == height(result.checks);
end

summaryTable = table(cohort,seed,finalConditionIds,identityAccuracy, ...
    identityEER,pufReliability,pufUniqueness,eligibleBits, ...
    worstScenarioReliability,sessionIdentityAccuracy,sessionIdentityEER, ...
    sessionPUFReliability,maximumSelectedCorrelation,checksPassed, ...
    cohortPassed, ...
    'VariableNames',{'Cohort','Seed','FinalConditionIds', ...
    'IdentityAccuracy','IdentityEER','PUFReliability','PUFUniqueness', ...
    'EligibleBits','WorstScenarioReliability','SessionIdentityAccuracy', ...
    'SessionIdentityEER','SessionPUFReliability', ...
    'MaximumSelectedCorrelation','ChecksPassed','CohortPassed'});
passCount = sum(cohortPassed);
passRate = passCount/numCohorts;
countGatePassed = passCount >= cfg.v33.requiredPassingCohorts;
rateGatePassed = passRate >= cfg.v33.requiredPassRate;
hypothesisSupported = countGatePassed && rateGatePassed;
aggregate.summaryTable = summaryTable;
aggregate.passCount = passCount;
aggregate.totalCohorts = numCohorts;
aggregate.passRate = passRate;
aggregate.requiredPassingCohorts = cfg.v33.requiredPassingCohorts;
aggregate.requiredPassRate = cfg.v33.requiredPassRate;
aggregate.countGatePassed = countGatePassed;
aggregate.rateGatePassed = rateGatePassed;
aggregate.hypothesisSupported = hypothesisSupported;
aggregate.decisionRule = sprintf( ...
    'At least %d of %d cohorts must pass all 10 frozen V3.2 gates.', ...
    cfg.v33.requiredPassingCohorts,cfg.v33.numCohorts);
end

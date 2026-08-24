function sessions = buildAcquisitionSessions(metadata,readsPerDecision)
%BUILDACQUISITIONSESSIONS Group consecutive reads from one presented core.
%   CoreId is used only as the evaluation label and to reconstruct simulated
%   acquisition sessions. Every decision receives exactly READSPERDECISION
%   measurements from one core and one operating condition. Leftovers are
%   reported and excluded rather than creating shorter sessions.

validateattributes(readsPerDecision,{'numeric'}, ...
    {'scalar','integer','positive','finite'});
if ~istable(metadata)
    error('TrafoDNA:InvalidSessionMetadata','Session metadata must be a table.');
end
required = {'CoreId','ConditionId','RepeatId'};
for k = 1:numel(required)
    if ~any(strcmp(metadata.Properties.VariableNames,required{k}))
        error('TrafoDNA:MissingSessionVariable', ...
            'Session metadata is missing variable "%s".',required{k});
    end
end

rows = cell(0,1);
coreIds = zeros(0,1);
conditionIds = zeros(0,1);
firstRows = zeros(0,1);
droppedMeasurements = 0;
enrolledCores = unique(metadata.CoreId(:))';
for coreId = enrolledCores
    coreConditions = unique(metadata.ConditionId(metadata.CoreId == coreId))';
    for conditionId = coreConditions
        selected = find(metadata.CoreId == coreId & ...
            metadata.ConditionId == conditionId);
        [~,order] = sort(metadata.RepeatId(selected));
        selected = selected(order);
        completeCount = floor(numel(selected)/readsPerDecision);
        usedCount = completeCount*readsPerDecision;
        droppedMeasurements = droppedMeasurements+numel(selected)-usedCount;
        for group = 1:completeCount
            groupRows = selected((group-1)*readsPerDecision+ ...
                (1:readsPerDecision));
            rows{end+1,1} = groupRows; %#ok<AGROW>
            coreIds(end+1,1) = coreId; %#ok<AGROW>
            conditionIds(end+1,1) = conditionId; %#ok<AGROW>
            firstRows(end+1,1) = groupRows(1); %#ok<AGROW>
        end
    end
end
if isempty(rows)
    error('TrafoDNA:NoCompleteSessions', ...
        'No complete acquisition session could be formed.');
end

sessions.rows = rows;
sessions.coreIds = coreIds;
sessions.conditionIds = conditionIds;
sessions.firstRows = firstRows;
sessions.readsPerDecision = readsPerDecision;
sessions.numSessions = numel(rows);
sessions.droppedMeasurements = droppedMeasurements;
end

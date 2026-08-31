function matches = v32ProtocolContractsEquivalent(first,second)
%V32PROTOCOLCONTRACTSEQUIVALENT Compare scientific contracts safely.
%   The final-opening token is a workflow secret, not a scientific setting.
%   Legacy bundles can contain it; public-source bundles intentionally omit
%   it. All result-relevant fields remain compared exactly.

first = localRemoveWorkflowSecrets(first);
second = localRemoveWorkflowSecrets(second);
matches = isequaln(first,second);
end

function value = localRemoveWorkflowSecrets(value)
workflowFields = {'finalConfirmationToken'};
for k = 1:numel(workflowFields)
    if isfield(value,workflowFields{k})
        value = rmfield(value,workflowFields{k});
    end
end
end

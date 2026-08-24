function createActiveFigures(dataset,splits,identityModel,developmentMetrics, ...
    finalEvaluation,analysis,cfg)
%CREATEACTIVEFIGURES Generate eight V3 challenge-response diagnostics.

visible = cfg.runtime.figureVisible;
challenges = cfg.active.challenges;
colors = lines(numel(cfg.active.waveforms));

% 1. Fixed challenge matrix.
fh = figure('Visible',visible,'Color','w'); hold on;
for k = 1:numel(cfg.active.waveforms)
    selected = strcmp({challenges.waveform},cfg.active.waveforms{k});
    scatter([challenges(selected).amplitudeScale], ...
        [challenges(selected).frequencyScale],55,colors(k,:),'filled', ...
        'DisplayName',cfg.active.waveforms{k});
end
grid on; xlabel('Field-amplitude scale'); ylabel('Frequency scale');
title('Preregistered 24-challenge matrix'); legend('Location','best');
localSave(fh,cfg,'01_active_challenge_matrix.png');

% 2. Core-specific energy response surfaces in the first known scenario.
energyIndex = find(strcmp(dataset.responseFeatureNames,'EnergyV2'),1);
fh = figure('Visible',visible,'Color','w'); hold on;
for coreId = 1:min(4,cfg.dataset.numCores)
    selected = dataset.metadata.CoreId == coreId & ...
        dataset.metadata.ConditionId == cfg.dataset.conditions(1).id;
    meanEnergy = squeeze(mean(dataset.responseTensor(selected,:,energyIndex),1));
    plot(1:numel(challenges),log10(max(meanEnergy,eps)),'o-', ...
        'DisplayName',sprintf('Core %d',coreId));
end
grid on; xlabel('Challenge ID'); ylabel('Mean log10 energy');
title('Core-specific active response surfaces'); legend('Location','best');
localSave(fh,cfg,'02_active_response_surfaces.png');

% 3. Enrollment identity embedding.
embedding = transformIdentityFeatures(identityModel, ...
    dataset.features(splits.train,:),dataset.metadata(splits.train,:));
coordinates = localPCA2(embedding);
fh = figure('Visible',visible,'Color','w');
scatter(coordinates(:,1),coordinates(:,2),14, ...
    dataset.metadata.CoreId(splits.train),'filled');
grid on; colorbar; xlabel('PC 1'); ylabel('PC 2');
title('V3 enrollment samples in active identity space');
localSave(fh,cfg,'03_active_identity_pca.png');

% 4. Development genuine/impostor verification distances.
fh = figure('Visible',visible,'Color','w'); hold on;
histogram(developmentMetrics.genuineDistances,30,'Normalization','probability', ...
    'FaceAlpha',0.65);
histogram(developmentMetrics.impostorDistances,30,'Normalization','probability', ...
    'FaceAlpha',0.55);
grid on; xlabel('Verification distance'); ylabel('Probability');
title('V3 development genuine/impostor distances');
legend({'Genuine','Impostor'},'Location','best');
localSave(fh,cfg,'04_active_development_distances.png');

% 5. Locked final confusion matrix.
fh = figure('Visible',visible,'Color','w');
imagesc(finalEvaluation.identityMetrics.confusionMatrix); axis image; colorbar;
xlabel('Predicted core'); ylabel('True core');
title('V3 preregistered final identity confusion matrix');
localSave(fh,cfg,'05_active_final_confusion.png');

% 6. Locked final ROC.
metrics = finalEvaluation.identityMetrics;
fh = figure('Visible',visible,'Color','w');
plot(metrics.falseAcceptRate,metrics.trueAcceptRate,'LineWidth',1.5); hold on;
plot(metrics.far(metrics.eerIndex),1-metrics.frr(metrics.eerIndex), ...
    'ro','MarkerFaceColor','r');
plot([0 1],[0 1],'k--'); grid on; axis([0 1 0 1]);
xlabel('False acceptance rate'); ylabel('True acceptance rate');
title(sprintf('V3 final ROC (EER = %.3f)',metrics.eer));
localSave(fh,cfg,'06_active_final_roc.png');

% 7. Locked final PUF-style Hamming distances.
fh = figure('Visible',visible,'Color','w'); hold on;
histogram(finalEvaluation.pufMetrics.intraHammingDistance,25, ...
    'Normalization','probability','FaceAlpha',0.65);
histogram(finalEvaluation.pufMetrics.interHammingDistance,25, ...
    'Normalization','probability','FaceAlpha',0.55);
grid on; xlabel('Normalized Hamming distance'); ylabel('Probability');
title(sprintf('V3 final raw fingerprint (%d bits)', ...
    finalEvaluation.pufMetrics.numSelectedBits));
legend({'Intra-core','Inter-core'},'Location','best');
localSave(fh,cfg,'07_active_final_hamming.png');

% 8. Final identity accuracy by preregistered scenario.
scenarioIds = unique(dataset.metadata.ConditionId(splits.finalHoldout),'stable');
accuracy = zeros(numel(scenarioIds),1);
finalConditionIds = dataset.metadata.ConditionId(splits.finalHoldout);
finalCoreIds = dataset.metadata.CoreId(splits.finalHoldout);
for k = 1:numel(scenarioIds)
    selected = finalConditionIds == scenarioIds(k);
    accuracy(k) = mean(finalEvaluation.identityPrediction(selected) == ...
        finalCoreIds(selected));
end
fh = figure('Visible',visible,'Color','w');
bar(scenarioIds,100*accuracy,'FaceColor',[0.25 0.55 0.75]);
grid on; ylim([0 105]); xlabel('Final scenario ID');
ylabel('Identity accuracy (%)'); title('V3 final accuracy by scenario');
localSave(fh,cfg,'08_active_final_accuracy_by_scenario.png');

if isempty(analysis)
    warning('TrafoDNA:EmptyActiveAnalysis','Active analysis structure was empty.');
end
end

function coordinates = localPCA2(data)
centered = data-mean(data,1);
[~,~,vectors] = svd(centered,'econ');
count = min(2,size(vectors,2));
coordinates = centered*vectors(:,1:count);
if size(coordinates,2)<2
    coordinates(:,2) = 0;
end
end

function localSave(fh,cfg,fileName)
set(fh,'PaperPositionMode','auto');
print(fh,fullfile(cfg.runtime.figureDirectory,fileName),'-dpng','-r160');
close(fh);
end

function createAllFigures(dataset, splits, identityModel, testMetrics, unseenMetrics, pufModel, pufMetrics, healthModel, analysis, cfg)
%CREATEALLFIGURES Generate signal, evaluation, and grouped-condition diagnostics.
%   Figures are written as numbered PNG files under CFG figure directory.

if isempty(dataset.rawExamples)
    warning('TrafoDNA:NoRawExamples','No raw examples were retained; raw plots skipped.');
    return;
end
visible = cfg.runtime.figureVisible;
example = dataset.rawExamples(1);
timeMs = 1e3*example.t;

% 1. Excitation field.
fh = figure('Visible',visible,'Color','w');
plot(timeMs,example.H,'LineWidth',1.3); grid on;
xlabel('Time (ms)'); ylabel('H (A/m)'); title('Excitation magnetic field H(t)');
localSave(fh,cfg,'01_excitation_field.png');

% 2. Barkhausen waveform.
fh = figure('Visible',visible,'Color','w');
plot(timeMs,1e3*example.signalV,'LineWidth',0.8); grid on;
xlabel('Time (ms)'); ylabel('Pickup voltage (mV)'); title('Simulated Barkhausen waveform');
localSave(fh,cfg,'02_barkhausen_signal.png');

% 3. Event phase distribution.
fh = figure('Visible',visible,'Color','w');
histogram(example.eventPhaseRad,24,'FaceColor',[0.25 0.45 0.75]); grid on;
xlabel('Excitation phase (rad)'); ylabel('Event count');
title('Barkhausen events versus excitation phase');
localSave(fh,cfg,'03_event_phase_distribution.png');

% 4. Frequency spectrum.
[frequencyHz,powerDb] = localSpectrum(example.signalV,example.sampleRateHz);
fh = figure('Visible',visible,'Color','w');
plot(frequencyHz/1e3,powerDb,'LineWidth',1.0); grid on;
xlabel('Frequency (kHz)'); ylabel('Relative power (dB)');
title('Barkhausen signal spectrum'); xlim([0 example.sampleRateHz/2/1e3]);
localSave(fh,cfg,'04_frequency_spectrum.png');

% 5. Same-core repeats.
sameCore = find([dataset.rawExamples.coreId] == example.coreId,2,'first');
fh = figure('Visible',visible,'Color','w'); hold on;
for k = 1:numel(sameCore)
    rec = dataset.rawExamples(sameCore(k));
    plot(1e3*rec.t,1e3*rec.signalV,'DisplayName',sprintf('Repeat %d',rec.repeatId));
end
grid on; xlabel('Time (ms)'); ylabel('Voltage (mV)');
title('Repeated measurements of the same virtual core'); legend('Location','best');
localSave(fh,cfg,'05_same_core_repeats.png');

% 6. Different cores.
differentCore = find([dataset.rawExamples.repeatId] == 1 & ...
    [dataset.rawExamples.conditionId] == 1, min(4,numel(unique([dataset.rawExamples.coreId]))),'first');
fh = figure('Visible',visible,'Color','w'); hold on;
for k = 1:numel(differentCore)
    rec = dataset.rawExamples(differentCore(k));
    plot(1e3*rec.t,1e3*rec.signalV,'DisplayName',sprintf('Core %d',rec.coreId));
end
grid on; xlabel('Time (ms)'); ylabel('Voltage (mV)');
title('Signals from different virtual cores'); legend('Location','best');
localSave(fh,cfg,'06_different_cores.png');

% 7. Development-holdout genuine/impostor distributions.
fh = figure('Visible',visible,'Color','w'); hold on;
histogram(unseenMetrics.genuineDistances,30,'Normalization','probability','FaceAlpha',0.65);
histogram(unseenMetrics.impostorDistances,30,'Normalization','probability','FaceAlpha',0.55);
grid on; xlabel('Verification distance'); ylabel('Probability');
title('Development-holdout genuine/impostor distances');
legend({'Genuine (intra)','Impostor (inter)'},'Location','best');
localSave(fh,cfg,'07_intra_inter_distances.png');

% 8. Known-condition confusion matrix without toolbox dependence.
fh = figure('Visible',visible,'Color','w');
imagesc(testMetrics.confusionMatrix); axis image; colorbar;
xlabel('Predicted core'); ylabel('True core');
title('Known-condition identity confusion matrix');
set(gca,'XTick',1:numel(testMetrics.coreIds),'YTick',1:numel(testMetrics.coreIds), ...
    'XTickLabel',testMetrics.coreIds,'YTickLabel',testMetrics.coreIds);
localSave(fh,cfg,'08_confusion_matrix.png');

% 9. Development-holdout ROC and EER.
fh = figure('Visible',visible,'Color','w');
plot(unseenMetrics.falseAcceptRate,unseenMetrics.trueAcceptRate,'LineWidth',1.5); hold on;
plot(unseenMetrics.far(unseenMetrics.eerIndex), ...
    1-unseenMetrics.frr(unseenMetrics.eerIndex),'ro','MarkerFaceColor','r');
plot([0 1],[0 1],'k--'); grid on; axis([0 1 0 1]);
xlabel('False acceptance rate'); ylabel('True acceptance rate');
title(sprintf('Development-holdout ROC (EER = %.3f)',unseenMetrics.eer));
localSave(fh,cfg,'09_roc_eer.png');

% 10. Hamming distances.
fh = figure('Visible',visible,'Color','w'); hold on;
histogram(pufMetrics.intraHammingDistance,25,'Normalization','probability','FaceAlpha',0.65);
histogram(pufMetrics.interHammingDistance,25,'Normalization','probability','FaceAlpha',0.55);
grid on; xlabel('Normalized Hamming distance'); ylabel('Probability');
title(sprintf('Known/development fingerprints (%d stable bits)', ...
    pufMetrics.numSelectedBits));
legend({'Intra-core','Inter-core'},'Location','best');
localSave(fh,cfg,'10_hamming_distances.png');

selected = splits.test | splits.unseen;
selectedMetadata = dataset.metadata(selected,:);
[allPrediction,~,~] = predictIdentity(identityModel,dataset.features(selected,:), ...
    selectedMetadata);

% 11. Accuracy grouped by condition temperature. Other condition variables
% vary jointly, so this is descriptive rather than a controlled sweep.
[temperatureValues,temperatureAccuracy] = localGroupedAccuracy( ...
    selectedMetadata.TemperatureK,allPrediction,selectedMetadata.CoreId);
fh = figure('Visible',visible,'Color','w');
plot(temperatureValues-273.15,100*temperatureAccuracy,'o-','LineWidth',1.4); grid on;
xlabel('Temperature (degC)'); ylabel('Identity accuracy (%)'); ylim([0 105]);
title('Identity accuracy grouped by condition temperature');
localSave(fh,cfg,'11_temperature_accuracy.png');

% 12. Accuracy grouped by condition sensor noise. Other condition variables
% vary jointly, so this is descriptive rather than a controlled sweep.
[noiseValues,noiseAccuracy] = localGroupedAccuracy(selectedMetadata.NoiseStdV, ...
    allPrediction,selectedMetadata.CoreId);
fh = figure('Visible',visible,'Color','w');
plot(1e6*noiseValues,100*noiseAccuracy,'s-','LineWidth',1.4); grid on;
xlabel('Noise standard deviation (uV)'); ylabel('Identity accuracy (%)'); ylim([0 105]);
title('Identity accuracy grouped by condition sensor noise');
localSave(fh,cfg,'12_noise_accuracy.png');

% 13. Health index grouped by simulated ageing. Stress and operating
% variables also vary across these condition groups.
[agingValues,meanHealthIndex] = localGroupedMean(selectedMetadata.AgingLevel, ...
    analysis.healthMetrics.healthIndex);
fh = figure('Visible',visible,'Color','w');
plot(agingValues,meanHealthIndex,'d-','LineWidth',1.4); grid on;
xlabel('Ageing level (0-1)'); ylabel('Distance from healthy centroid');
title('Health index grouped by simulated ageing level');
localSave(fh,cfg,'13_aging_health_index.png');

% 14. Identity PCA view.
trainFeatures = dataset.features(splits.train,:);
trainIds = dataset.metadata.CoreId(splits.train);
identityEmbedding = transformIdentityFeatures(identityModel, trainFeatures, ...
    dataset.metadata(splits.train,:));
identity2D = localPCA2(identityEmbedding);
fh = figure('Visible',visible,'Color','w');
scatter(identity2D(:,1),identity2D(:,2),12,trainIds,'filled'); grid on; colorbar;
xlabel('PC 1'); ylabel('PC 2');
title('Enrollment samples in identity feature space');
localSave(fh,cfg,'14_identity_pca.png');

% 15. Before/after separation for health labels.
healthLabels = selectedMetadata.HealthState;
raw2D = localPCA2(standardizeFeatures(dataset.features(selected,:), ...
    healthModel.featureMean,healthModel.featureStd,healthModel.activeFeatures));
separated2D = localPad2(analysis.testHealthCoordinates);
fh = figure('Visible',visible,'Color','w');
subplot(1,2,1); localScatterLabels(raw2D,healthLabels,healthModel.healthClasses);
title('Before identity removal'); xlabel('PC 1'); ylabel('PC 2'); grid on;
subplot(1,2,2); localScatterLabels(separated2D,healthLabels,healthModel.healthClasses);
title('After identity residualization'); xlabel('Health axis 1'); ylabel('Health axis 2'); grid on;
localSave(fh,cfg,'15_identity_health_separation.png');

% 16. Explicit identity degradation by health state.
fh = figure('Visible',visible,'Color','w');
bar(100*analysis.identityAccuracyByHealth.IdentityAccuracy,'FaceColor',[0.30 0.60 0.45]);
grid on; ylim([0 105]); ylabel('Identity accuracy (%)'); xlabel('Health state');
set(gca,'XTick',1:height(analysis.identityAccuracyByHealth), ...
    'XTickLabel',analysis.identityAccuracyByHealth.HealthState);
title('Identity accuracy under each health state');
localSave(fh,cfg,'16_identity_accuracy_by_health.png');

% Prevent unused-input warnings while keeping the public signature explicit.
if isempty(pufModel)
    warning('TrafoDNA:EmptyPUFModel','PUF model was empty.');
end
end

function localSave(fh,cfg,fileName)
set(fh,'PaperPositionMode','auto');
print(fh,fullfile(cfg.runtime.figureDirectory,fileName),'-dpng','-r160');
close(fh);
end

function [frequencyHz,powerDb] = localSpectrum(x,fs)
n = numel(x);
X = fft(x-mean(x));
count = floor(n/2)+1;
power = abs(X(1:count)).^2;
powerDb = 10*log10(power/max(max(power),eps)+eps);
frequencyHz = (0:count-1)'*fs/n;
end

function [groups,accuracy] = localGroupedAccuracy(values,predicted,trueValues)
groups = unique(values);
accuracy = zeros(size(groups));
for k = 1:numel(groups)
    selected = values == groups(k);
    accuracy(k) = mean(predicted(selected) == trueValues(selected));
end
end

function [groups,averages] = localGroupedMean(values,data)
groups = unique(values);
averages = zeros(size(groups));
for k = 1:numel(groups)
    averages(k) = mean(data(values == groups(k)));
end
end

function coordinates = localPCA2(data)
centered = data-mean(data,1);
[~,~,V] = svd(centered,'econ');
if isempty(V)
    coordinates = zeros(size(data,1),2);
else
    coordinates = centered*V(:,1:min(2,size(V,2)));
    coordinates = localPad2(coordinates);
end
end

function coordinates = localPad2(coordinates)
if size(coordinates,2) < 2
    coordinates(:,2) = 0;
end
coordinates = coordinates(:,1:2);
end

function localScatterLabels(coordinates,labels,classes)
hold on;
markers = {'o','s','d','^','v','>'};
for k = 1:numel(classes)
    selected = strcmp(labels,classes{k});
    scatter(coordinates(selected,1),coordinates(selected,2),15, ...
        markers{1+mod(k-1,numel(markers))},'filled','DisplayName',classes{k});
end
legend('Location','best');
end

# TrafoDNA

**Stokastik Barkhausen Gürültüsü Kullanılarak Transformatör Nüvelerinin Sanal Manyetik Parmak İziyle Tanımlanması**

TrafoDNA, aynı nominal özelliklere sahip transformatör nüvelerindeki mikroyapısal farklılıkların Barkhausen gürültüsü üzerinden sanal bir kimlik oluşturup oluşturamayacağını araştıran, yalnızca MATLAB ile çalışan sayısal bir fizibilite projesidir. Proje ayrıca nüve kimliğini sıcaklık, mekanik stres ve termal yaşlanma değişimlerinden ayırmayı dener.

> **Bilimsel sınır:** Bu çalışma fiziksel ölçüm veya deneysel doğrulama içermez. Üretilen sinyaller fiziksel olarak yorumlanabilir fakat indirgenmiş stokastik bir modelden gelir. Sonuçlar gerçek transformatör performansı olarak sunulmamalıdır.

## Araştırma hipotezi

> Aynı nominal özelliklere sahip transformatör nüvelerinde mikroyapısal farklılıklardan kaynaklanan stokastik Barkhausen sinyalleri, değişken çalışma koşulları altında güvenilir bir sanal manyetik parmak izi oluşturabilir mi ve bu kimlik bilgisi nüvenin sağlık değişimlerinden ayrıştırılabilir mi?

## Temel yaklaşım

Barkhausen etkisi, ferromanyetik malzemedeki domain duvarlarının dış manyetik alan altında sürekli değil, kesikli sıçramalarla hareket etmesinden kaynaklanır. TrafoDNA'da olay yoğunluğu:

- manyetik alanın etkin koersivite çevresindeki konumuna,
- alanın değişim hızına `dH/dt`,
- domain-pinning yoğunluğuna,
- mikroyapısal düzensizliğe,
- domain etkileşimine,
- sıcaklığa, mekanik strese ve yaşlanmaya

bağlanır. Her sanal nüve sabit bir mikroyapısal parametre takımı taşır. Ölçüm tekrarı değiştiğinde bu kimlik parametreleri korunur; yalnızca stokastik olay gerçekleşmeleri ve ölçüm gürültüsü yeniden üretilir.

Model ABBM yaklaşımından esinlenmiştir; tam bir mikromanyetik veya sonlu eleman çözümü değildir. Denklemler ve kabuller [MODEL.md](MODEL.md) içinde açıklanmıştır.

## Gereksinimler

- MATLAB R2020b veya daha yeni bir sürüm önerilir.
- Temel çalışma yolu özel toolbox gerektirmez.
- Statistics and Machine Learning Toolbox bulunursa isteğe bağlı ECOC-SVM eğitilebilir; varsayılan olarak kapalıdır.
- Simulink, Python, harici veri kümesi ve fiziksel donanım kullanılmaz.

## Çalıştırma

MATLAB'da proje klasörünü açıp aşağıdaki komutları çalıştırın:

```matlab
addpath(genpath(pwd));
results = main();
```

Varsayılan deney:

- 20 sanal nüve,
- 10 çalışma koşulu,
- koşul başına 20 tekrar,
- toplam 4000 Barkhausen örneği

üretir. Ham sinyallerin tamamı bellekte tutulmaz. Her sinyal oluşturulduktan sonra özellikleri çıkarılır; yalnızca görselleştirme için seçilmiş az sayıda ham kayıt saklanır.

### Hızlı deneme

```matlab
addpath(genpath(pwd));
cfg = defaultConfig();
cfg.dataset.numCores = 5;
cfg.dataset.numConditions = 5;
cfg.dataset.repetitions = 5;
cfg.dataset.trainRepeats = 1:3;
cfg.dataset.validationRepeats = 4;
cfg.dataset.testRepeats = 5;
cfg.dataset.unseenConditionIds = 5;
cfg.dataset.conditions = cfg.dataset.conditions(1:5);
for k = 1:numel(cfg.dataset.conditions)
    cfg.dataset.conditions(k).isUnseen = (k == 5);
end
results = main(cfg);
```

## Otomatik testler

```matlab
run_tests
```

veya:

```matlab
testResults = runAllTests();
```

Testler şunları denetler:

- aynı seed ile birebir aynı sinyalin oluşması,
- farklı nüvelerin farklı sabit parametreler alması,
- sinyal ve özelliklerde `NaN`/`Inf` bulunmaması,
- özellik boyutlarının tutarlılığı,
- eğitim/doğrulama/test/görülmeyen koşul kümelerinin çakışmaması,
- toolbox'sız kimlik modelinin çalışması,
- FAR ve FRR sınırları,
- EER hesabı,
- intra-core mesafelerin genel olarak inter-core mesafelerden küçük olması,
- PUF ölçütlerinin geçerli aralıkta olması.

## Proje akışı

1. `defaultConfig` bütün fiziksel ve sayısal ayarları oluşturur.
2. `createVirtualCore` nüveye özgü sabit mikroyapısal parametreleri üretir.
3. `generateExcitation` sinüs, üçgen veya trapez `H(t)` alanını oluşturur.
4. `simulateBarkhausen` faza bağlı avalanche olaylarını ve pickup gerilimini üretir.
5. `extractFeatures` zaman, olay, spektrum, faz ve Haar özelliklerini çıkarır.
6. `splitDataset` tekrar gruplarını ve tamamen görülmeyen koşulları ayırır.
7. Kimlik modeli Öklid veya düzenlenmiş Mahalanobis uzaklığıyla çalışır.
8. PUF aşaması kararsız bitleri enrollment verisinden eler.
9. Sağlık modeli, her nüvenin centroid'ini çıkardıktan sonra residual PCA uygular.
10. Performans ölçütleri, CSV/MAT sonuçları ve 16 grafik üretilir.

## Çıkarılan özellikler

- RMS, tepe değer, crest factor
- skewness, kurtosis ve sıfır geçiş oranı
- olay sayısı, olay genliği ve olaylar arası zaman istatistikleri
- spektral merkez, bant genişliği ve spektral entropi
- dört frekans bandının normalize enerjisi
- uyarma döngüsünün pozitif/negatif yarı enerji oranları
- Barkhausen envelope genişliği
- dört seviye Haar detay enerjisi ve son yaklaşım enerjisi

Haar özellikleri proje içinde yazılmıştır; Wavelet Toolbox gerekmez.

## Kimlik doğrulama ve PUF ölçütleri

Kimlik modeli aşağıdaki çıktıları üretir:

- identification accuracy,
- confusion matrix,
- genuine/impostor mesafe dağılımları,
- güven skoru,
- FAR, FRR, ROC ve EER.

İkili parmak izi aşaması ise şunları hesaplar:

- reliability,
- uniqueness,
- uniformity,
- bit aliasing,
- intra/inter Hamming distance,
- tahmini min-entropy.

Buradaki “PUF” ifadesi, fiziksel güvenlik iddiası değil, PUF literatüründeki ölçütlerin sanal nüve parmak izlerine uygulanması anlamındadır.

## Kimlik ve sağlık ayrıştırması

Önce bütün özellikler eğitim verisiyle standartlaştırılır. Ardından her nüvenin eğitim centroid'i çıkarılır. Bu işlem nüveye özgü üretim ofsetlerinin büyük kısmını kaldırır. Kalan residual özelliklere PCA uygulanır ve dört sağlık durumu en yakın centroid yöntemiyle değerlendirilir:

- `healthy`
- `mechanical_stress`
- `thermal_aging`
- `combined`

## Üretilen dosyalar

`results/` altında:

- `trafodna_results.mat`
- `trafodna_features.csv`
- `identity_accuracy_by_health.csv`
- `figures/01_excitation_field.png`
- `figures/02_barkhausen_signal.png`
- `figures/03_event_phase_distribution.png`
- `figures/04_frequency_spectrum.png`
- `figures/05_same_core_repeats.png`
- `figures/06_different_cores.png`
- `figures/07_intra_inter_distances.png`
- `figures/08_confusion_matrix.png`
- `figures/09_roc_eer.png`
- `figures/10_hamming_distances.png`
- `figures/11_temperature_accuracy.png`
- `figures/12_noise_accuracy.png`
- `figures/13_aging_health_index.png`
- `figures/14_identity_pca.png`
- `figures/15_identity_health_separation.png`
- `figures/16_identity_accuracy_by_health.png`

oluşturulur. Başarı değerleri kod içine yazılmamıştır; yalnızca simülasyon çalıştırıldıktan sonra hesaplanır.

## Dizin yapısı

```text
TrafoDNA/
├── main.m
├── run_tests.m
├── README.md
├── MODEL.md
├── config/
├── models/
├── features/
├── dataset/
├── identity/
├── health/
├── evaluation/
├── visualization/
├── tests/
├── utils/
└── results/figures/
```

## Önemli sınırlamalar

1. Model, domain duvarlarını uzaysal olarak çözmez.
2. Nüve laminasyon geometrisi, tane haritası ve gerçek sensör transfer fonksiyonu doğrudan modellenmez.
3. Parametre dağılımları literatür-temelli deneysel kalibrasyon yerine makul sayısal aralıklardır.
4. Modelin ayırt edilebilirlik üretmesi, gerçek nüvelerin aynı doğrulukla ayırt edilebileceği anlamına gelmez.
5. Simülasyonda kimlik parametreleri ile koşul parametreleri tasarım gereği ayrılmıştır; gerçek dünyada bu ayrım daha karmaşıktır.
6. Min-entropy sonucu kriptografik güvenlik kanıtı değildir.

## Gerçek ölçüme geçiş

Gelecekte `simulateBarkhausen` yerine bir veri yükleyici eklenebilir. Gerçek pickup bobini ölçümlerinde her kayıt için `signalV`, `sampleRateHz` ve eşzamanlı `H(t)` sağlanırsa mevcut özellik çıkarımı, kimlik, PUF ve sağlık katmanları korunabilir. Gerçek deneyde sıcaklık, uyarma genliği/frekansı, sensör konumu, sıkma torku ve nüve geçmişi kontrollü biçimde kaydedilmelidir.

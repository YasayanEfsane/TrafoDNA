# TrafoDNA Sayısal Modeli

## 1. Kapsam

TrafoDNA modeli, transformatör nüvesindeki Barkhausen etkinliğinin istatistiksel ve fiziksel olarak yorumlanabilir bir indirgenmiş temsilidir. Amaç tam mikromanyetik çözüm yapmak değil; uyarma, mikroyapı, çalışma koşulu ve gözlenen yüksek frekanslı pickup gerilimi arasında test edilebilir bir hesaplama zinciri kurmaktır.

Model şu seviyeleri birbirinden ayırır:

- **Sabit nüve parametreleri:** Sanal üretim kimliği.
- **Çalışma koşulları:** Sıcaklık, uyarma, gürültü ve sensör kazancı.
- **Sağlık değişkenleri:** Mekanik stres ve yaşlanma.
- **Stokastik gerçekleşme:** Aynı nüvenin farklı ölçümlerindeki avalanche olayları.

## 2. Uyarma alanı

Uyarma alanı

\[
H(t)=H_0+H_a w(2\pi f t)
\]

olarak tanımlanır. Burada `w`, sinüzoidal, üçgen veya trapezoidal birim dalga olabilir. Her çalışma koşulu `H_a` ve `f` için ayrı ölçek katsayıları taşır. Sayısal `dH/dt`, MATLAB `gradient` fonksiyonuyla örnekleme aralığına göre hesaplanır.

## 3. Sanal nüve kimliği

Her nüve için aşağıdaki sabit parametreler bir kez örneklenir:

\[
\Theta_i=\{H_{c,i},\rho_{p,i},c_i,D_i,\lambda_{0,i},\tau_i,A_i,s_i,\mathbf{a}_i,\boldsymbol\phi_i\}.
\]

Burada:

- `Hc`: koersivite,
- `rho_p`: bağıl pinning yoğunluğu,
- `c`: domain etkileşim katsayısı,
- `D`: mikroyapısal düzensizlik,
- `lambda_0`: temel avalanche olay hızı,
- `tau`: domain etkinliği sönüm zaman sabiti,
- `A`: temel pickup darbe genliği,
- `s`: spektral kayma,
- `a` ve `phi`: manyetizasyon fazına bağlı sabit mikroyapısal modülasyon katsayılarıdır.

Parametreler sınırlı normal dağılımlardan üretilir. `coreId` ve merkezi `rngSeed`, parametrelerin tekrar üretilebilir olmasını sağlar.

## 4. Çalışma koşulunun parametrelere etkisi

Sıcaklık, stres ve yaşlanma için boyutsuz çarpanlar:

\[
F_T=1+k_T(T-T_0),
\]

\[
F_\sigma=1+k_\sigma |\sigma|,
\]

\[
F_a=1+k_a a
\]

olarak kullanılır. Etkin koersivite, pinning yoğunluğu, disorder seviyesi, olay hızı, zaman sabiti ve darbe genliği bu çarpanlarla değiştirilir. Bu bağıntılar fenomenolojiktir; belirli bir çelik sınıfına ait deneysel kalibrasyon olarak yorumlanmamalıdır.

## 5. ABBM-esinli olay yoğunluğu

Model, ABBM yaklaşımındaki sürülen ve düzensiz pinning ortamında ilerleyen domain duvarı fikrini olay yoğunluğu düzeyine indirger. Her zaman örneğindeki temel avalanche yoğunluğu:

\[
\lambda(t)=\lambda_{\mathrm{eff}}
\left(0.05+\left|\frac{\dot H(t)}{\dot H_{\max}}\right|^{0.72}\right)
\left(0.10+W_c(t)\right)F_i(\varphi(t))
\]

şeklindedir. Koersivite penceresi:

\[
W_c(t)=\exp\left[-\frac{1}{2}
\left(\frac{|H(t)|-H_{c,\mathrm{eff}}}{\sigma_c}\right)^2\right]
\]

olup domain-wall aktivitesini `+/-Hc` çevresinde yoğunlaştırır. Böylece olaylar beyaz gürültü gibi zamandan bağımsız oluşmaz.

Nüveye özgü faz modülasyonu:

\[
F_i(\varphi)=\max\left(0.15,
1+\sum_{m=1}^{8}a_{i,m}\cos(m\varphi+\phi_{i,m})\right)
\]

olarak tanımlanır. `a` ve `phi` katsayıları aynı nüvenin bütün ölçümlerinde sabittir.

Bir örnekleme aralığındaki birincil olay olasılığı:

\[
p_k=\min(\lambda(t_k)\Delta t,0.30)
\]

olarak sınırlandırılır.

## 6. Avalanche dallanması

Komşu olaylar arasında kısa süreli korelasyon oluşturmak için sönümlenen etkinlik durumu kullanılır:

\[
q_k=e^{-\Delta t/\tau}q_{k-1}+r_k,
\]

burada `r_k`, gerçekleşen olayın normalize büyüklüğüdür. İkincil olay olasılığı `q_k` ve domain etkileşim katsayısıyla artırılır. Bu yapı tam ABBM stokastik diferansiyel denklemi değildir; avalanche kümelenmesini düşük hesaplama maliyetiyle temsil eden ABBM-esinli bir ayrık süreçtir.

Olay genliği log-normal olarak oluşturulur:

\[
A_k=A_{\mathrm{eff}}\exp(D_{\mathrm{eff}}\xi_k)
\left(0.25+0.75\frac{|\dot H_k|}{|\dot H|_{\max}}\right)(1+0.30q_k),
\]

burada `xi_k`, standart normal rassal değişkendir. Darbenin işareti `dH/dt` yönüne bağlanır.

## 7. Pickup bobini ve ölçüm modeli

Her avalanche darbesi için sönümlü sinüzoidal sensör çekirdeği kullanılır:

\[
g(t)=e^{-t/\tau_s}\sin(2\pi f_s t),\qquad t\ge0.
\]

Olay treninin `g(t)` ile evrişimi temiz pickup sinyalini üretir. Daha sonra FFT alanında kosinüs geçişli idealize bir bant geçiren filtre uygulanır. Ölçülen sinyal:

\[
v_m(t)=G_s v_{clean}(t)+\sigma_n n_c(t)
\]

şeklindedir. `n_c(t)`, birinci dereceden renklendirilmiş ve standart sapması normalize edilmiş gürültüdür.

## 8. Özellik uzayı

Ham sinyal yerine zaman, event, spektrum, manyetizasyon yarı-döngüsü ve Haar enerji özellikleri saklanır. Spektral olasılık:

\[
p_j=\frac{P_j}{\sum_k P_k}
\]

ve normalize spektral entropi:

\[
S=-\frac{\sum_j p_j\log_2 p_j}{\log_2 N_f}
\]

olarak hesaplanır.

Event tespiti, median absolute deviation tabanlı sağlam gürültü kestirimi kullanır:

\[
\hat\sigma=\frac{\operatorname{median}(|x-\operatorname{median}(x)|)}{0.67449}.
\]

Yerel maksimumlar `3.5*sigma` eşiği ve minimum olay uzaklığıyla seçilir.

## 9. Kimlik modeli

Özellikler yalnızca eğitim kümesinin ortalama ve standart sapmasıyla normalize edilir. Her nüve için centroid hesaplanır. Düzenlenmiş ortak sınıf-içi kovaryans:

\[
\Sigma_r=(1-\alpha)\Sigma_w+\alpha\bar\sigma^2 I
\]

ve Mahalanobis uzaklığı:

\[
d_i(\mathbf{x})=
\sqrt{(\mathbf{x}-\boldsymbol\mu_i)^T\Sigma_r^{-1}
(\mathbf{x}-\boldsymbol\mu_i)}
\]

kullanılır. En düşük uzaklık kimliği verir. Öklid uzaklığı yapılandırmadan seçilebilir.

## 10. PUF-tarzı ikili parmak izi

Her özelliğin global enrollment medyanı eşik kabul edilir. Nüve centroid'i eşikten büyükse bit `1`, değilse `0` olur. Tekrar ölçümlerindeki bit uyuşma oranı reliability olarak kullanılır. Kararsız veya bütün nüvelerde aynı kalan bitler elenir.

- Reliability: `1 - ortalama intra-Hamming mesafesi`
- Uniqueness: nüve referansları arasındaki ortalama Hamming mesafesi
- Uniformity: referans bitlerindeki `1` oranı
- Bit aliasing: her bit konumunda nüveler arası `1` oranı
- Min-entropy: bit bazında en olası değerden hesaplanan muhafazakâr kestirim

Bu hesaplar kriptografik PUF kanıtı değildir.

## 11. Kimlik ve sağlık ayrıştırması

Her eğitim örneğinden ait olduğu nüvenin centroid'i çıkarılır:

\[
\mathbf{r}_{ij}=\mathbf{z}_{ij}-\boldsymbol\mu_i.
\]

Residual matrise SVD/PCA uygulanır. Açıklanan varyansın varsayılan `%95`'ini taşıyan, en fazla sekiz bileşen korunur. Sağlık sınıfları bu residual koordinatlarda düzenlenmiş Mahalanobis uzaklığıyla değerlendirilir.

Bu yaklaşım kimlik değişkenliğini tamamen yok etmeyi garanti etmez; yalnızca eğitimde görülen nüve ofsetlerini azaltır.

## 12. Sayısal bölme stratejisi

- Koşul 9 ve 10 eğitim sırasında hiç görülmez.
- Bilinen koşullarda tekrar 1-12 eğitim, 13-16 doğrulama, 17-20 test içindir.
- Aynı örnek birden fazla bölmede bulunamaz.
- Standardizasyon, centroid, kovaryans ve PUF eşikleri yalnızca eğitim verisinden hesaplanır.

## 13. Modelin geçerlilik sınırı

Model aşağıdakileri çözmez:

- gerçek tane geometrisi ve domain duvarı topolojisi,
- laminasyonlar arası elektromanyetik bağlaşım,
- uzaysal akı dağılımı,
- gerçek pickup bobini konumu ve nüve geometrisi,
- deneysel olarak kalibre edilmiş sıcaklık/stres katsayıları,
- gerçek yaşlanma mekanizmalarının kimyasal ve metalürjik ayrıntıları.

Bu nedenle proje bir algoritma ve deney tasarımı ön çalışmasıdır. Gerçek bir transformatör kimlik doğrulama sistemi olduğunu iddia etmez.

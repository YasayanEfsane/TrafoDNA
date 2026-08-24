# TrafoDNA Numerical Model

## 1. Scope

TrafoDNA is a statistically and physically interpretable reduced model of Barkhausen activity in transformer cores. Its purpose is not a full micromagnetic solution. It provides a testable computational chain from excitation and latent microstructure to a high-frequency pickup voltage, identity representation, binary fingerprint, and health representation.

The model separates four levels:

- **Fixed core parameters:** a virtual manufacturing identity.
- **Operating conditions:** temperature, excitation, measurement noise, and sensor gain.
- **Health variables:** mechanical stress and thermal ageing.
- **Stochastic realization:** avalanche events that vary between repeated measurements.

## 2. Excitation field

The applied field is

\[
H(t)=H_0+H_a w(2\pi f t),
\]

where `w` is a sinusoidal, triangular, or trapezoidal unit waveform. Each condition scales `H_a` and `f`. MATLAB `gradient` computes the numerical field derivative using the sampling interval.

## 3. Latent core identity

Each core receives one fixed parameter set:

\[
\Theta_i=\{H_{c,i},\rho_{p,i},c_i,D_i,\lambda_{0,i},\tau_i,A_i,s_i,
\mathbf{a}_i,\boldsymbol\phi_i\}.
\]

The terms denote coercivity, relative pinning density, interaction coefficient, disorder, base avalanche rate, activity time constant, pickup-pulse amplitude, spectral shift, and fixed phase-modulation coefficients. Bounded normal distributions generate these values. `coreId` and the central random seed make the identity reproducible.

## 4. Operating and health effects

The phenomenological factors are

\[
F_T=1+k_T(T-T_0), \qquad
F_\sigma=1+k_\sigma |\sigma|, \qquad
F_a=1+k_a a.
\]

They modify effective coercivity, pinning density, disorder, avalanche rate, time constant, and pulse amplitude. These relationships are numerical assumptions and must not be interpreted as calibration to a specific electrical-steel grade.

## 5. ABBM-inspired event intensity

The model reduces the driven-domain-wall idea of ABBM to an event-intensity process:

\[
\lambda(t)=\lambda_{\mathrm{eff}}
\left(0.05+\left|\frac{\dot H(t)}{\dot H_{\max}}\right|^{0.72}\right)
\left(0.10+W_c(t)\right)F_i(\varphi(t)),
\]

with coercive window

\[
W_c(t)=\exp\left[-\frac{1}{2}
\left(\frac{|H(t)|-H_{c,\mathrm{eff}}}{\sigma_c}\right)^2\right].
\]

The fixed core-specific phase modulation is

\[
F_i(\varphi)=\max\left(0.15,
1+\sum_{m=1}^{8}a_{i,m}\cos(m\varphi+\phi_{i,m})\right).
\]

The primary event probability in one sample interval is

\[
p_k=\min(\lambda(t_k)\Delta t,0.30).
\]

## 6. Avalanche clustering and amplitude

A decaying activity state creates short-range event correlation:

\[
q_k=e^{-\Delta t/\tau}q_{k-1}+r_k.
\]

The secondary-event probability increases with `q_k` and the interaction coefficient. Event amplitudes are log-normal:

\[
A_k=A_{\mathrm{eff}}\exp(D_{\mathrm{eff}}\xi_k)
\left(0.25+0.75\frac{|\dot H_k|}{|\dot H|_{\max}}\right)(1+0.30q_k).
\]

The sign follows the direction of `dH/dt`. This is an ABBM-inspired discrete process, not the complete ABBM stochastic differential equation.

## 7. Pickup and measurement model

Each event excites a damped sinusoidal response:

\[
g(t)=e^{-t/\tau_s}\sin(2\pi f_s t), \qquad t\geq0.
\]

The event train is convolved with `g(t)` and passed through an FFT-domain band-pass with cosine transitions. The measured voltage is

\[
v_m(t)=G_s v_{\mathrm{clean}}(t)+\sigma_n n_c(t),
\]

where `n_c(t)` is normalized first-order colored noise.

## 8. Feature representation

TrafoDNA stores features rather than every waveform. V2 includes:

- RMS, absolute peak, crest factor, skewness, kurtosis, and zero-crossing rate;
- event count, amplitude, interval, and excitation-normalized event descriptors;
- spectral centroid, bandwidth, entropy, and normalized band energies;
- positive/negative half-cycle energy ratios;
- 12 phase-bin event ratios and 12 phase-bin energy ratios;
- envelope width in seconds and excitation cycles;
- four Haar detail energies and one approximation energy.

The phase bins expose the fixed `F_i(φ)` structure that V1 largely discarded. Event detection uses a median-absolute-deviation noise estimate:

\[
\hat\sigma=\frac{\operatorname{median}(|x-\operatorname{median}(x)|)}{0.67449}.
\]

## 9. Condition-robust identity transform

Raw features are standardized with enrollment statistics only. Let `z` be a standardized feature row and `u` the standardized measurable-condition vector containing temperature, excitation amplitude, excitation frequency, noise standard deviation, and sensor gain. The ridge nuisance model is

\[
\hat B=\arg\min_B \|Z-UB\|_F^2+\lambda\|B\|_F^2.
\]

The residual identity representation is

\[
R=Z-U\hat B.
\]

Stress, ageing, health labels, and core identities are not predictors in this model. Query-time operating metadata is required when the normalizer is enabled.

V2.1 additionally centers these residuals within each enrolled core and uses SVD to learn dominant within-core nuisance directions `V_q`. Identity features are projected onto their orthogonal complement:

\[
R_\perp=R(I-V_qV_q^T).
\]

This learns a shared condition-variation subspace without using stress or health labels. The projection is fixed after enrollment and therefore does not require query-time health metadata.

For each residual dimension, a training-only Fisher score is computed:

\[
J_j=\frac{S_{B,j}}{S_{W,j}+\epsilon}.
\]

The highest-ranked dimensions are retained. Core centroids and a shared within-core covariance are then estimated. The regularized covariance is

\[
\Sigma_r=(1-\alpha)\Sigma_w+\alpha\bar\sigma^2I,
\]

and identity uses Mahalanobis distance

\[
d_i(x)=\sqrt{(x-\mu_i)^T\Sigma_r^{-1}(x-\mu_i)}.
\]

Feature count, `α`, and the number of removed nuisance components are selected with leave-one-condition-out validation. For each fold, one complete known condition is absent from enrollment and is evaluated using its validation repetitions. The objective combines mean condition accuracy, worst-condition accuracy, and mean EER. Test and deliberately unseen conditions are never used.

## 10. Verification metrics

The genuine score is the distance to the enrolled true-core centroid. Impostor scores are distances to every other centroid. Sweeping a threshold yields FAR, FRR, ROC, and EER. Validation EER and unseen-condition EER are reported separately in V2.

## 11. Differential PUF-style fingerprint

PUF enrollment operates in the fitted identity embedding. Candidate responses include each coordinate `r_j` and each difference `r_j-r_k`. Enrollment medians create all binary thresholds and core references. Candidate selection considers:

- mean repeat reliability across enrolled cores;
- validation-repeat reliability and worst-known-condition reliability;
- bit aliasing bounds across the population;
- normalized distance from the threshold;
- redundancy measured by reference-bit correlation.

Only candidates meeting the stability gates are selected up to the configured maximum. Lower-ranked candidates may be used only to satisfy the minimum response length. The selected reference for each core remains the enrollment median. Reported metrics include reliability, uniqueness, uniformity, bit aliasing, intra/inter Hamming distances, and a bitwise min-entropy estimate. These are PUF-style diagnostics, not a cryptographic proof.

## 12. Identity/health separation

The standardized enrollment centroid of each core is subtracted:

\[
r_{ij}=z_{ij}-\mu_i.
\]

Training health labels provide a Fisher ranking that removes residual dimensions dominated by nonspecific noise. PCA/SVD is then applied to the selected residual matrix. The configured variance fraction, capped at eight components, defines the health coordinates. Regularized Mahalanobis distance to health-class centroids produces the prediction and health index.

## 13. Split and leakage policy

- Conditions 9 and 10 are excluded from fitting and retained as the observed development holdout.
- Conditions 11 and 12 are preregistered final holdouts and remain excluded from fitting, validation, and PUF bit selection.
- Known-condition repetitions 1–12 train, 13–16 validate, and 17–20 test.
- A sample belongs to at most one partition.
- Standardization, nuisance regression, feature ranking, centroids, covariance, and PUF enrollment use training data only.
- Validation selects two identity hyperparameters.
- Test and unseen labels are evaluation-only.

## 14. Multi-read session protocol

Single-read performance remains the primary diagnostic. V2.2 defined its three-read operational decision before the first final-holdout run. Consecutive measurements from one presented core under one condition form a session; incomplete trailing groups are excluded and counted.

Identity sessions take the feature-wise median of the three reads and apply the unchanged fitted identity transform. PUF sessions take the median of each continuous selected response before applying the enrollment threshold. No vote uses the true core label. `CoreId` is used only to reconstruct which simulated acquisitions belong to the same presented device and to score the final decision.

The three-read metrics are supplementary and never overwrite single-read accuracy, EER, or reliability.

## 15. V3 persistent active pinning map

V3 leaves the passive simulator unchanged and defines a separate compact active model. Core `i` receives 256 fixed virtual pinning sites

\[
P_i=\{h_j,w_j,b_j,q_j,s_j,\eta_{T,j},\eta_{\sigma,j},\eta_{a,j}\}_{j=1}^{256},
\]

where `h` is the activation threshold, `w` is the event weight, `b` is the magnetisation branch, `q` is the rate exponent, `s` is the spectral tendency, and the three `η` terms describe site-level temperature, stress, and ageing sensitivity. This map is generated once from the core seed and is never redrawn between scenarios or challenges.

For scenario `e`, the effective threshold is

\[
h_{i,j,e}^{*}=h_{i,j}(1+\eta_{T,j}\Delta T)
(\text{stress and ageing factors})+b_jH_{\mathrm{reset}}.
\]

For challenge `c`, field amplitude, frequency, waveform sweep factor, and a fixed site-waveform preference determine an activation probability. Sixteen Bernoulli activation cycles estimate the repeated site activity. The compact response contains activation, weighted count, energy, peak amplitude, threshold moments, spectral moments, branch balance, rate moment, and circular phase coordinates.

The map makes core identity persistent while leaving activation and measurement stochastic. It is a reduced theoretical mechanism rather than a spatial domain-wall simulation.

## 16. V3 differential challenge representation

The active challenge matrix is the Cartesian product of three waveforms, four field amplitudes, and two frequencies. Let `x_{i,e,r,c,k}` denote positive response coordinate `k` for core `i`, scenario `e`, repeated sweep `r`, and challenge `c`. Relative to reference challenge `c_0`, V3 forms

\[
d_{i,e,r,c,k}=\log(x_{i,e,r,c,k}+\epsilon)
-\log(x_{i,e,r,c_0,k}+\epsilon).
\]

Signed phase coordinates use ordinary differences. The absolute transformed reference response is retained, giving 288 features per complete sweep. A common multiplicative sensor gain cancels from every log-difference coordinate.

The existing enrollment-only standardization, measurable-condition residualization, Fisher selection, covariance regularization, centroid verification, differential PUF-style bit screening, and three-sweep median evaluation are then applied without access to V3 final rows.

Identity and PUF-style enrollment use separate training-only transforms. The identity classifier chooses its feature count, covariance shrinkage, and nuisance-subspace size by known-condition holdout. The fixed PUF transform retains 96 Fisher-ranked coordinates and removes 20 dominant within-core nuisance directions before thresholds are enrolled. PUF candidate scoring weights enrollment reliability by 0.20, validation reliability by 0.30, and worst-known-condition reliability by 0.50. This separation prevents an identity-accuracy objective from silently selecting a representation with unstable raw bits.

## 17. V3 split and decision boundary

- Scenario IDs 101–108 are known conditions.
- Scenario IDs 109–114 are the development holdout. IDs 111–114 were
  reclassified before preregistration because a shadow design model used them.
- Scenario IDs 115–118 were the untouched preregistered final holdout for the
  first V3 run. Their six-dimensional coordinates are Halton points 23–26 in
  bases 2, 3, 5, 7, 11, and 13. They are now observed and locked.
- Sweeps 1–4 enroll, 5–6 validate, and 7–9 test within known scenarios.
- Stress, ageing, health labels, and core labels are forbidden nuisance predictors.
- Ten final checks are fixed in `docs/V3_PREREGISTRATION.md`, including a
  minimum of 32 strictly eligible raw bits with fallback disabled.
- V2.2 conditions 11–12 remain observed historical evidence and are not reused.

## 18. Validity boundary

The model does not solve real grain geometry, domain-wall topology, lamination coupling, spatial flux, coil placement, calibrated material coefficients, or metallurgical ageing chemistry. The V3 pinning sites are persistent numerical latent variables, not measured defects. This is an algorithm and experiment-design study. Physical claims require independently manufactured cores, calibrated acquisition hardware, controlled nuisance variables, preregistered splits, uncertainty intervals, and replication.

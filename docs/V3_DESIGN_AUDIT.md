# V3 Pre-Freeze Design Audit

## Purpose

This audit records the numerical checks used to choose the V3 protocol before its untouched final evaluation. It is design evidence, not a TrafoDNA result. The audit used a short NumPy shadow implementation of the same response equations because MATLAB was not available in the authoring environment. NumPy and MATLAB do not share identical random streams or numerical pipelines, so the values below must not be reported as MATLAB benchmark metrics.

## Shadow observations

The initial 24-challenge, three-cycle design showed strong multiclass separation, but its PUF-style response was too sensitive to joint health and environmental shifts. On candidate stress scenarios 111–114, approximate raw reliability was below the fixed V3 target when the PUF reused the identity classifier's transform.

The pre-freeze audit compared longer within-challenge averaging and a separate enrollment-only PUF stability transform. The selected design uses 16 cycles per challenge, 96 Fisher-ranked PUF coordinates, 20 removed within-core nuisance components, and strict validation/worst-condition bit screening. In the shadow check on candidate scenarios 111–114, this design produced approximately 0.93 raw reliability, 0.91 worst-scenario reliability, 0.94 three-sweep reliability, and 0.526 uniqueness.

These observations guided the protocol; they are not independent evidence for it.

## Holdout consequence

Because scenarios 111–114 influenced protocol selection, they are permanently classified as development evidence. They cannot be called untouched or final. The actual final scenarios are 115–118, generated mechanically from Halton points 23–26 after the design choices above were fixed. No shadow or MATLAB model output from scenarios 115–118 was inspected before preregistration.

## Frozen decisions

- 24 fixed waveform/amplitude/frequency challenges;
- 16 excitation cycles per challenge;
- 256 persistent pinning sites per core;
- a separate 96-coordinate, 20-nuisance-component PUF transform;
- strict 0.90/0.90/0.88 enrollment, validation, and worst-known-condition bit gates;
- scenarios 109–114 as development and 115–118 as final;
- ten final acceptance checks, including at least 32 strictly eligible bits,
  with all ten required for support.

Any post-final improvement must use a new final scenario design and a new protocol version.

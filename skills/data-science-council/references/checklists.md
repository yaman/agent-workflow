# Checklists

Attach the relevant checklist to the shared problem block. Personas answer every item with either a finding (severity + evidence class) or an explicit "not applicable — because [reason]".

## Document checklist (any text with a statistical/causal/learning claim)

1. **Claim decomposition** — is this prediction ("what correlates"), prescription ("what causes"), or strategy-level ("what the company should do")? Each has a different evidence bar.
2. **Sample reality** — unit structure (clusters vs observations), N, event counts (wins, not just activities), base rates vs the anchor table.
3. **Minimum detectable effect** — is the claimed effect detectable at this N? (Anchor power numbers.)
4. **Causal identification** — selection into treatment, unobserved confounders, compliance handling (ITT vs as-performed).
5. **Feedback loop** — does the system's own policy shape the data it learns from? Exploration? Propensity logging? OPE?
6. **Multiple comparisons** — comparison count, family definition, correction (Holm/BH), stopping rules.
7. **Labels** — who labels, verification, open-vs-negative class, delay awareness, self-report vs observation.
8. **Strategy-level claims** — n/p ratio, variation in the regressors, endogeneity, exchangeability for pooling.
9. **Overclaim check** — falsifiability, evidence class of every cited statistic, "learns/optimal/auto" language vs actual design.
10. **Feed reality** — every assumed data input: does it exist, flow, and hold up? (Data Engineer.)

## Experiment-config checklist (configs shaped like assignment_model_v1)

1. **Assignment** — randomized? Who decides? Blind-ish? Mode (sticky/crossover/switchback) fits the entity and the interference structure?
2. **Washout** — declared, sized to the cycle, crossover contamination addressed?
3. **Power** — metric, unit structure, declared minimum effect, documented MDE at the planned sample (INCONCLUSIVE is the honest verdict when undetectable).
4. **Pre-registration** — hypothesis, metric, sample size, decision rule written before go-live; declared stopping rule.
5. **Family & correction** — full comparison set for the period; Holm for surfaced guidance, BH (q≤0.10) for exploratory.
6. **ITT** — analysis compares as-assigned; adherence measured separately; no re-sorting by compliance.
7. **Labels** — outcome definition, who verifies, open outcomes never the negative class, maturity window declared.
8. **Exploration** — permanent exploration fraction and propensity logging in the config, or explicitly absent with a reason.
9. **Proxy-vs-gold** — if the metric is a proxy, what is the gold outcome, and how is the gap monitored?
10. **Feed reality** — every input the config assumes (activity stream, outcome labels, assignment enforcement): does it exist in the target deployment? (Data Engineer.)

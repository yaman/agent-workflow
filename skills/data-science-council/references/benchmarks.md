# Benchmarks — verified anchor numbers

Purpose: personas argue from these numbers; Benchmarks and Overclaim personas verify and update them during runs (web access). When a run contradicts an anchor, the fact-checker reports the new value with its source; the anchor table is updated only by explicit user approval.

## Win rates (B2B)
- Median QUALIFIED win rate: ~20–22% (mid-market $10–50K ACV ≈ 24%; upper-mid $50–100K ≈ 18%; enterprise >$100K ≈ 15%). Sources: Optifai Pipeline Study 2026 (N=939); WinsAbove 2026 synthesis (Bridge Group/ICONIQ/Pavilion).
- All-opportunity median: ≈ 9%. Source: Ebsta+Pavilion 2025 (9.3M opportunities, 583 CRMs).
- Note: surveyed win rates run 4–6pp higher than CRM-extracted; qualified vs all-opportunity denominators swing ±5–10pp.

## Sales cycles (B2B SaaS)
- Median 84 days first-meeting→closed-won (P25 41d, P75 167d). By ACV: $15–50K → 58d; $50–100K → 84d; $100–250K → 124d; $250–500K → 168d; $500K+ → 224d. Sources: Optifai 2026; WinsAbove 2026 (ICONIQ data).

## Deal volumes per rep
- Mid-market AE: 40–80 deals/yr → 10–20 wins/yr at 24%. Enterprise AE: ~40 qualified opps/yr → ~6 wins/yr at 15%. Sources: Rework 2026; SaaStr/Lemkin 2024.

## Power (two-proportion, α=0.05, 80% power; verified computation)
- Detect 25%→35%: ~330 deals per group (~660 total).
- Detect 20%→30%: ~290 per group.
- Detect 25%→30%: ~1,250 per group (~2,500 total).
- Detect 15%→20%: ~900 per group.

## Model-building rules
- Events per variable (EPV) ≥ 10 per predictor (Peduzzi 1996; threshold contested by van Smeden 2016 — problems persist with correlated predictors; treat 10 as a floor, 20–50 under stepwise selection).
- At a 20% win rate, each predictor costs ~50 deals (10 events / 0.20).
- Multilevel (binary outcomes): ~50 clusters for level-2 SEs; ~100 clusters for level-2 variance SEs (McNeish & Stapleton 2016); SEs ~15% too small at 30 groups (Maas & Hox 2005). Cross-level interactions need ~50 clusters × 20 units (Hox 1998/2010).

## Multiple comparisons
- At α=0.05: 10 tests → 40% chance of ≥1 false positive; 20 → 64%; 50 → 92%; 100 → 99.4% (~5 expected false positives).
- Holm 1979: step-down FWER control, valid under arbitrary dependence, dominates plain Bonferroni.
- Benjamini-Hochberg 1995: FDR control, valid under independence/positive regression dependence.

## Data quality (CRM)
- 75% of CRM users admit fabricating data at least sometimes (Validity 2022, n=1,241).
- 24% of CRM admins report <50% of data accurate (Validity 2024).
- B2B contact data decays 22–30%/year (Validity 2022/2024 + industry analyses, via the 2026-08-28 research corpus).

## Label timing
- Naive labeling of not-yet-converted as lost under-predicts the true conversion rate by ~20–21% (Chapelle 2014, KDD; display-ad delayed feedback — direct analogue to open deals).

## Causal claims — the benchmark for "would this survive due diligence"
- Observational vs randomized: estimates off by a factor of ~3 in half of 15 field studies (Gordon et al. 2019, Marketing Science).
- B2B sales causal literature: ~1 credible IV estimate of a sales action exists (Zhang 2022, Stanford GSB): effect of initiating contact ≈ +1.4pp, strongly heterogeneous.
- MMM (strategy-level analog): ≥30 monthly observations needed for correct coefficient signs alone (Venkatraman 2025); non-identifiability of model form (Dew et al. 2024); ITS designs need 8–12 points per side, ≥24 for adequate coverage (Penfold & Zhang 2013; Turner 2021).

## Vendor-claim sanity
- Gong/Clari "95% forecast accuracy" = revenue-forecast accuracy from self-reported case studies; no vendor publishes an independently audited deal-level AUC.
- Salesforce Einstein scoring requires ≥200 closed opps/24mo (≥20% won and lost) before it trains; Oracle requires 1,000.

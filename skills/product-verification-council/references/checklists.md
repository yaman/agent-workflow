# Checklists

Mode checklists, included verbatim in the shared problem block. Each persona reviews against the checklist for the active mode.

## Product mode (default)

1. **Claims** — every claim the product makes (performance, capacity, security, UX, market). Is it verified, verifiable, or marketing?
2. **Architecture** — system design, boundaries, coupling, data flow, failure modes.
3. **Code quality** — clean code, tests, CI, error handling, fullstack contract.
4. **Deployment** — CI/CD, IaC, environment parity, rollback, observability.
5. **Performance** — SLOs, load behavior, capacity plan, degradation.
6. **Security** — authN/authZ, secrets, supply chain, infra security, threat model.
7. **UX** — research evidence, IA, usability, feedback loops.
8. **Accessibility** — WCAG 2.2, screen readers, keyboard, contrast, motion.
9. **Domain** — does the product match how the domain actually works?
10. **Skeptic** — does the demo survive contact with reality?

## Release mode (full roster, release bar)

Everything in product mode, plus:

1. **Release bar** — is there a definition of done? A release checklist? A rollback plan?
2. **Sign-off** — who signs off? Is there a release owner? A go/no-go meeting?
3. **Post-release** — is there a monitoring plan? An incident response? A support channel?
4. **Veto seats** — Architect, SRE/Performance, DevSecOps, Product Owner must each explicitly state: "I approve / I block, because…"

## Targeted mode (subset roster)

1. The named lenses only — no findings outside the named scope.
2. Each named lens reviews against its own checklist section (from `references/personas.md`).
3. No veto escalation — targeted reviews are advisory unless the user asks for a release bar.

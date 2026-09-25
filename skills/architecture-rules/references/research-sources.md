# Research sources (2025–2026)

Where the language, TDD, and clean-code sections of `architecture-rules` come from. All URLs accessed September 2026.

## Rust

**Official / rust-lang.org**
- https://blog.rust-lang.org/2025/02/20/Rust-1.85.0/ (edition 2024 + async closures)
- https://doc.rust-lang.org/edition-guide/rust-2024/index.html · /prelude.html · /rpit-lifetime-capture.html · /temporary-tail-expr-scope.html
- https://doc.rust-lang.org/stable/book/ch11-03-test-organization.html
- https://doc.rust-lang.org/cargo/reference/workspaces.html · /features.html
- https://rust-lang.github.io/api-guidelines/flexibility.html
- https://rust-lang.github.io/async-book/part-reference/structured.html
- https://rust-lang.github.io/rust-clippy/stable/index.html

**Tokio / serde / miette / insta / proptest**
- https://tokio.rs/tokio/topics/shutdown · https://docs.rs/tokio/latest/tokio/task/ · /struct.JoinSet.html
- https://serde.rs/container-attrs · /field-attrs.html · https://github.com/serde-rs/serde/issues/2384 (deny_unknown_fields + flatten footgun)
- https://docs.rs/miette/latest/miette/ · https://insta.rs/docs/quickstart/ · https://proptest-rs.github.io/proptest/proptest/vs-quickcheck.html

**Microsoft engineering guidance**
- https://microsoft.github.io/rust-guidelines/guidelines/project/index.html · /guidelines/performance/
- https://microsoft.github.io/RustTraining/engineering-book/ch08-compile-time-and-developer-tools.html · ch12-tricks-from-the-trenches.html
- https://github.com/microsoft/RustTraining/blob/main/rust-patterns-book/src/ch11-serialization-zero-copy-and-binary-data.md

**Authoritative individuals**
- https://www.effective-rust.com/newtype.html
- https://bertptrs.nl/2025/02/23/rust-edition-2024-annotated.html · https://jacar.es/en/rust-edition-2024-what-really-changes-day-to-day/
- https://hackmd.io/@rust-lang-team/rJks8OdYa (async fn in traits — send-bound problem)
- https://redandgreen.co.uk/hybrid-trait-pattern/rust-programming/ (generics vs dyn)
- https://www.atharvapandey.com/post/rust/rust-prod-hexagonal/
- https://rs4ts.dev/08-error-handling/08-best-practices/ · /15-serialization/05-attributes/
- https://andrewodendaal.com/rust-error-handling-patterns-production/
- https://www.azdanov.dev/articles/2025/rust-error-guidelines
- https://leapcell.io/blog/type-safe-ids-and-data-validation-in-rust-web-apis-with-newtype-pattern
- https://www.shuttle.dev/blog/2024/03/21/testing-in-rust
- https://oneuptime.com/blog/post/2026-01-26-rust-integration-tests/view (DB isolation patterns)
- https://deepwiki.com/testcontainers/testcontainers-rs/7.2-testing-patterns-and-best-practices

## Svelte

**Official docs**
- https://svelte.dev/docs/svelte/best-practices · /$state · /$derived · /$effect · /$props · /$bindable · /snippet · /compiler-warnings · /testing · /typescript · /v5-migration-guide
- https://svelte.dev/docs/kit/load · /form-actions · /state-management · /types · /project-structure
- https://svelte.dev/blog/runes · https://svelte.dev/blog/zero-config-type-safety

**Community (2025–2026)**
- https://mainmatter.com/blog/2025/03/11/global-state-in-svelte-5/ (runes class-store pattern)
- https://blog.openreplay.com/state-management-svelte-5-runes/
- https://loopwerk.io/articles/2025/svelte-5-stores/ (stores-vs-runes counter-position)
- https://aidanbleser.com/blog/posts/dont-use-effect (event-driven over effect-driven)
- https://fullstacksveltekit.com/blog/svelte-5-runes ($state.raw)
- https://scottspence.com/posts/testing-with-vitest-browser-svelte-guide
- https://helpmetest.com/blog/testing-sveltekit/
- https://hugosum.com/blog/end-to-end-type-safety-with-svelte5-and-sveltekit2 ($types)
- https://accessibility.build/guides/svelte-accessibility
- https://github.com/sveltejs/kit/discussions/7579 (colocation — Rich Harris)
- https://www.stanza.dev/courses/svelte-5-runes/advanced-props/svelte-5-runes-bindable-mastery ($bindable)
- https://blog.codercops.com/blog/svelte-5-runes-production-reactivity-2026

## TDD

**Canonical**
- https://newsletter.kentbeck.com/p/canon-tdd (Canon TDD) · /p/composable-tests · /p/design-in-tdd · /p/the-generalize-step-in-tdd
- https://martinfowler.com/articles/is-tdd-dead/ · https://martinfowler.com/bliki/TestPyramid.html · https://martinfowler.com/articles/practical-test-pyramid.html
- https://blog.thecodewhisperer.com/permalink/integrated-tests-are-a-scam (Rainsberger)
- https://kentcdodds.com/blog/write-tests (Testing Trophy) · /blog/testing-implementation-details
- https://www.testdesiderata.com (Beck's test desiderata)
- https://github.com/testdouble/contributing-tests/wiki/London-school-TDD
- https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices
- https://stryker-mutator.io/docs/ (mutation testing)

**AI-era TDD (2025–2026)**
- https://www.builder.io/blog/test-driven-development-ai (2025)
- https://blog.yfzhou.fyi/posts/tdd-llm/ ("who guards the guard")
- https://www.augmentcode.com/guides/spec-tdd-shippable-ai-generated-code (Beck interview; reward hacking)
- https://github.com/mauricioTechDev/tdd-ai (state-machine enforcement)
- https://8thlight.com/insights/tdd-effective-ai-collaboration
- https://loreai.dev/blog/red-green-refactor-claude-code (one-test-at-a-time)
- https://aclanthology.org/2026.eacl-long.70.pdf (TDFlow, EACL 2026 — humans write tests, agents solve)
- https://www.pubstack.com/blog/2025/07/22/test-driven-ai.html (spec→tests→code)
- https://medium.com/effortless-programming/better-ai-driven-development-with-test-driven-development-d4849f67e339 (Eric Elliott)
- https://getautonoma.com/blog/unit-vs-integration-vs-e2e-testing (AI-era pyramid shift)
- https://bug0.com/knowledge-base/testing-pyramid

## Clean code

**The 2024–25 debate**
- https://github.com/johnousterhout/aposd-vs-clean-code (Ousterhout vs Martin exchange)
- https://bugzmanov.github.io/cleancode-critique/ (critical analysis)
- https://theaxolot.wordpress.com/2024/05/08/dont-refactor-like-uncle-bob-please/
- https://pvs-studio.com/en/blog/posts/1157/ (Martin vs Muratori)
- https://sids.in/posts/aposd-vs-clean-code (summary)

**Readability research**
- https://www.se.cs.uni-saarland.de/publications/docs/HoSeHo17.pdf (full words ~19% faster)
- https://brains-on-code.github.io/descriptive-compound-identifier-names.pdf (compound names ~14%)
- https://doi.org/10.1109/icpc.2017.27 (parameter names matter most)
- https://doi.org/10.1109/tse.2020.2976920 (How Developers Choose Names)
- https://ar5iv.labs.arxiv.org/html/2103.11008 (intermediate variables)
- https://link.springer.com/article/10.1007/s10664-023-10425-5 (comment smells taxonomy)
- https://www.se.cs.uni-saarland.de/publications/docs/APB+25.pdf (eye-tracking comment study)

**Complexity / structure**
- https://www.sonarsource.com/docs/CognitiveComplexity.pdf (Sonar whitepaper)
- https://sourcegraph.com/blog/code-complexity · /blog/cyclomatic-complexity-what-it-is-and-how-to-reduce-it
- https://codeintelligently.com/blog/code-complexity-cyclomatic-cognitive-change (complexity × churn)
- https://prickles.org/tenet/guard-clauses/S4 (guard clauses)
- http://c2.com/ppr/wiki/WikiPagesAboutRefactoring/ShortMethods.html (data-flow extraction)

**Duplication / tidying**
- https://sandimetz.com/blog/2016/1/20/the-wrong-abstraction
- https://www.codewithjason.com/duplication/ (undetected duplication)
- https://newsletter.kentbeck.com/p/the-life-changing-magic-of-tidying (Tidy First)
- https://dryisoverrated.com/

**AI agents**
- https://www.alphaxiv.org/abs/2605.20049 (cleanliness cuts agent cost, not capability)
- https://akitaonrails.com/en/2026/04/20/clean-code-for-ai-agents/ (grep-navigability, file size)
- https://maintainable.software/agentic-engineering-part-2-agentic-codebase-principles/ (locality, blast radius)
- https://stackoverflow.blog/2026/03/26/coding-guidelines-for-ai-agents-and-people-too/
- https://www.engineering.fyi/article/harness-engineering-leveraging-codex-in-an-agent-first-world (OpenAI Harness)
- https://agenticoding.ai/agent-friendly-code (agents amplify patterns)

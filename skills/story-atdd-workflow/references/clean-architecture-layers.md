# Clean Architecture Layers — frontend + backend

Default architecture for story-atdd projects (unless a `decision` row says
otherwise): **clean architecture in BOTH frontend and backend**. This file is
the layer map, the dependency rule, the per-layer test seams, and the top-down
vertical slice build order the tech_brief and the per-AC subagents follow.

## The dependency rule

Dependencies point INWARD. Inner layers know nothing about outer layers; outer
layers depend on abstractions (ports) declared by the inner layers. The
infrastructure layer implements those ports. The acceptance test drives the
slice from the outermost surface; the slice is built top-down in that same
direction.

## Backend layers

| Layer | Responsibility | Typical contents | Test seam |
|---|---|---|---|
| **delivery** | HTTP/transport boundary: routes, controllers, request/response mapping, SSE | route handlers, DTOs, middleware | acceptance test (${acceptance.e2e}) + **contract provider test** (verifies the consumer contract) + route/controller unit tests with a stubbed application layer |
| **application** | use cases, orchestration, transaction boundaries | use case classes, ports (interfaces) the delivery layer calls | unit tests with stubbed domain + real or fake ports |
| **domain** | business rules, entities, value objects, domain services — no I/O | entities, value objects, domain logic | pure unit tests (fastest, no I/O) |
| **infrastructure** | adapters: repositories, db config, external clients, metering | repository implementations, db schema/migrations, engine client | integration tests against the real/fake adapter; contract tests proving the port is honored |

## Frontend layers

| Layer | Responsibility | Typical contents | Test seam |
|---|---|---|---|
| **presentation** | what the user sees: components, pages, state bindings, styling | Svelte components, CSS, a11y attributes | acceptance test (${acceptance.e2e}) + component tests with stubbed application layer |
| **application** | UI state, orchestration of domain + infrastructure, view models | stores, view models, use-case facades | unit tests with stubbed domain + fake API client |
| **domain** | frontend business rules, formatting, invariants | pure functions, value objects, formatters | pure unit tests |
| **infrastructure** | API client, SSE/websocket transport, persistence, metering relay | fetch/SSE clients, token/cost relays | **contract consumer test** (records the contract against a mock provider) — NOT a mock-transport unit test; contract tests proving the port is honored |

## The frontend → backend handoff (consumer-driven contracts)

The boundary between the frontend infrastructure layer and the backend
delivery layer is governed by a **consumer-driven contract** (`${acceptance.contract}`,
default `pact`) — not by a mock-based client unit test. The contract is the
seam between the two sides.

### Consumer side (frontend infrastructure layer)

1. **Write the consumer test** — the expected interaction: method, path,
   request body, expected status, expected response fields (exact shapes the
   UI actually consumes).
2. **Run it: RED** — the API client does not exist yet.
3. **Implement the API client** — exactly enough to satisfy the interaction.
4. **Run it: GREEN** — the test records the contract (pact file).

### Provider side (backend delivery layer)

1. **Run the provider test against the consumer contract** — the
   contract is the test; it drives the route/controller.
2. **Run it: RED** — the route does not exist yet.
3. **Implement the route/controller** — exactly enough to satisfy the
   contract.
4. **Run it: GREEN** — the provider honors the consumer contract.

The provider test runs BEFORE the delivery layer's own unit tests — the
contract is the first test of the backend side. The pact file is the shared
artifact: the consumer publishes it, the provider verifies it.

## Top-down vertical slice build order (per AC)

The acceptance test is written FIRST and run RED. Then the slice is built
top-down, in the direction the acceptance test drives, layer by layer, with
inner TDD at every layer (unit test → implementation → green):

```
frontend presentation → frontend application → frontend domain →
frontend infrastructure (API client) →
backend delivery (route/controller) → backend application (use case) →
backend domain → backend infrastructure (repository/db config)
```

### The per-layer TDD loop

For EACH layer in the build order, the subagent runs the same inner loop
before moving to the next layer:

1. **Write the layer's unit test** — the seam for that layer (see the layer
   tables above), stubbing the layers below it (ports/fakes).
2. **Run it: RED** — for the right reason (the logic does not exist yet).
3. **Implement the layer's logic** — exactly enough to make the unit test
   green, nothing more.
4. **Run it: GREEN.**

The acceptance test is the OUTER red loop — it stays red until the last layer
lands. Each layer's unit test is the INNER red loop — a layer is never
implemented without its own failing test first.

### Rules

- **Skip empty layers.** If a layer has nothing to add for the current AC,
  skip it — write exactly enough code to turn the red AC green, nothing more.
- **Persistence is the LAST layer, not the first.** The db config is built
  only when the slice actually reaches it.
- **Ports before adapters.** When a layer needs a dependency from an inner
  layer, declare the port (interface) at the boundary first; the adapter is
  implemented when the infrastructure layer is reached.
- **The contract is the handoff.** The frontend infrastructure layer's consumer
  test records the contract; the backend delivery layer's provider test
  verifies it. No mock-transport client unit test replaces the
  consumer contract.
- **The acceptance test stays green at the end of the slice.** Each inner unit
  test is green as it is written; the outer red loop only closes when the last
  layer lands.

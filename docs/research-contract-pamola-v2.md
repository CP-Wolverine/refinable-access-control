<!--
Revision: PAMoLa evidence update (v2)
Generated: 2026-09-17
Verification marker: includes the PAMoLa representation boundary and unchanged RQ1-RQ5.
-->

# Research contract

This document freezes the scientific scope of the A*-oriented revision before
implementation and measurement changes are made. Every final paper claim must
be backed by the evidence identified here.

## Central claim

The proposed approach is a model-integrated refinement layer for authorization.
It encodes representative policy patterns associated with RBAC, ABAC, ReBAC,
and EBAC, while deriving same-level specificity and cross-level precedence from
the protected domain model instead of declaration order or manually maintained
global priorities.

The project does **not** currently claim complete conformance with the full
RBAC family, XACML, Auctoritas, or every EBAC/ReBAC language feature.

## PAMoLa representation boundary

The implementation and paper distinguish four layers that must not be
conflated:

1. **PAMoLa Core** supplies ordia, custodianship, linguistic types, identity,
   properties, and uninterpreted `hasPotency` and `hasDeclaredType` slots.
2. **The LML profile** interprets those slots as a multi-level classification
   discipline, including absent-potency-as-zero, the potency-step rule, and a
   single declared ontological classifier.
3. **HUTN** is a family of textual projections of PAMoLa clades. A HUTN profile
   changes rendering, not the authoritative model meaning.
4. **The access-control layer** consumes a validated canonical graph and adds
   policy declarations, applicability, refinement, decisions, and provenance.

`hasCustodian` is a containment, locality, and naming relation. Ontological
level membership may be derived by following custodianship to an explicitly
identified level container, but custodianship itself is not an ontological
level relation. Stable PAMoLa PIDs are the canonical identities used across
translation and provenance; FQNs, SUNs, and numeric HUTN labels are
presentation or serialization identifiers with different stability scopes.

The supplied `brakesystem.fhas` is initially a PAMoLa/HUTN parsing and
rule-compilation fixture. It is not counted as an RQ1 access-control domain
unless a separate, independently specified authorization scenario, policy set,
request corpus, and expected-decision oracle are added.

## Research questions

### RQ1 — Policy-model coverage and generality

To what extent can one unchanged refinement kernel encode representative core
RBAC, ABAC, ReBAC, and EBAC policy patterns across structurally different
domains?

Required evidence:

- a feature matrix using `native`, `translated`, and `unsupported` labels;
- EMR, eDocument, and project-management domain instantiations;
- traceability from every source policy to declarations, constraints, and
  expected requests;
- confirmation that domain changes do not modify the generic kernel;
- traceability from each PAMoLa ordium used by a policy to the canonical graph
  facts consumed by the kernel;
- confirmation that the same validated PAMoLa-to-Datalog boundary is used for
  all PAMoLa-backed domains.

### RQ2 — Semantic and implementation correctness

Does the executable implementation conform to the formal refinement semantics
for applicability, intra-level specificity, nearest-level preemption,
same-level conflict handling, and deny-by-default behavior?

Required evidence:

- formal definitions and proof obligations for termination, determinism,
  order independence, unique nearest-level selection, and conflict locality;
- an implementation-independent decision/provenance oracle;
- expected-versus-actual results for the complete finite workloads;
- edge-case, metamorphic, and bounded generated-model tests;
- equivalence tests across supported Datalog engines when more than one engine
  is reported;
- HUTN parsing and reference-resolution tests with an explicit profile, root
  context, imports, and PAMoLa/Core version;
- PAMoLa Core and LML well-formedness tests, including single custodianship,
  custodian-cycle rejection, potency-step validation, and single-valued
  declared typing;
- an independently checked translation oracle for explicit atoms, derived rule
  heads, ordered body atoms, arguments, and stable identities;
- round-trip or canonical-equivalence tests across every HUTN profile for which
  semantic preservation is claimed, with ambiguous input rejected loudly.

### RQ3 — Policy-evolution safety and locality

Compared with explicit-priority Datalog, Auctoritas, and XACML, how accurately
does model-derived refinement localize the effects of defaults, subtype rules,
object refinements, context rules, and instance exceptions?

Required evidence:

- versioned policy snapshots for a predefined evolution sequence;
- independently specified intended decision deltas;
- observed intended, missed, and unintended decision changes;
- explicit precedence/combining elements and policy elements changed;
- conflict introduction/removal and deciding-level changes;
- a same-engine ablation: model-derived refinement versus explicit priorities
  on Nemo;
- PID-based identity tracking so that renaming, re-custody, and serialization
  changes are separated from semantic policy changes.

### RQ4 — Representational and computational complexity

What representational overhead and computational cost do the proposed approach
and the comparison systems incur as policy and domain complexity increase?

Required evidence:

- theoretical analysis for the exact rule-language fragments used;
- normalized semantic-unit counts, not source lines alone;
- notation-independent counts of ordia, graph edges, policy declarations,
  atoms, arguments, and relationship traversals;
- separate HUTN parsing, reference resolution, Core/LML validation, Datalog
  compilation, materialization, decision, provenance, throughput, and memory
  measurements;
- scaling of facts, declarations, level depth/branching, applicable-rule
  density, conflict density, and relationship-path length;
- repeated trials, fixed seeds, environment/version disclosure, and uncertainty
  intervals.

### RQ5 — Provenance faithfulness and compactness

Are decision explanations faithful, complete, non-duplicative, stable under
declaration reordering, and compact enough for manual inspection?

Required evidence:

- a canonical provenance schema;
- oracle-backed winner, shadowing, preemption, and conflict tests;
- representative complete traces;
- size distributions computed from unique serialized components;
- PIDs as canonical provenance identities, with names and FQNs retained only
  as human-facing labels;
- stability tests for declaration reordering, HUTN-profile changes, and benign
  renaming that preserves the referenced PIDs;
- no claim of human comprehensibility without a corresponding user study.

## Comparison subjects

The evaluation compares systems, not incomparable labels:

1. Proposed refinement semantics executed by Nemo.
2. Nemo ablation using explicit priority/combining facts.
3. Auctoritas as the EBAC-oriented comparison, subject to executable-artifact
   availability and validation.
4. XACML 3.0 using a named, versioned policy-decision-point implementation.

If Auctoritas cannot be executed reproducibly, it may be used for semantic and
representation comparison but not for performance claims.

## Fairness rules

- Use the same domain facts, request corpus, evolution operations, and
  independent decision oracle wherever the systems support equivalent
  semantics.
- Give every comparison system a natural faithful encoding; do not construct a
  deliberately weak baseline.
- Preserve XACML's `Permit`, `Deny`, `NotApplicable`, and `Indeterminate`
  outcomes until an explicit PEP-level mapping is applied.
- Separate language/semantic effects from execution-engine effects.
- Separate theoretical complexity, representation size, empirical runtime,
  and human authoring effort.
- Report unsupported features rather than silently weakening the policy.
- Do not use XML character count or lines of code as the primary complexity
  metric.

## Evidence gates

No final result enters the manuscript unless it is:

1. generated by a versioned command from a clean checkout;
2. checked against an independent oracle where correctness is claimed;
3. accompanied by the exact input, configuration, software versions, and seed;
4. reproducible by continuous integration or a documented benchmark machine;
5. emitted in a machine-readable form from which the paper table or figure is
   generated.

## Implementation order

1. Repair the current artifact and establish a real build/test baseline.
2. Freeze the PAMoLa Core/LML/HUTN/access-control representation boundary.
3. Obtain and version the PAMoLa 1.0.0 Core seed and reference HUTN ware, or
   explicitly scope the artifact to a bounded FHAS importer.
4. Normalize `brakesystem.fhas`, validate its intended domain rules, and use it
   as a parsing and rule-compilation conformance fixture.
5. Separate the generic kernel from front-end translation, domains, policies,
   metrics, and expected-decision oracles.
6. Implement a canonical decision/provenance API and conformance oracle.
7. Add semantic edge cases and generated-model tests.
8. Migrate the validated program to Nemo and retain cross-engine conformance.
9. Add versioned evolution scenarios and the same-engine ablation.
10. Add eDocument and project-management instantiations.
11. Add validated Auctoritas and XACML encodings.
12. Run true input-scaling benchmarks and generate manuscript artifacts.

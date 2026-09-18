# Refinable Access Control over Multi-Level Domain Models

This repository contains the executable research artifact for model-integrated
policy refinement over multi-level domain models.

## Current status

The code on `main` is the **legacy EMR semantic baseline**. It currently uses
AbcDatalog 0.8.0. The research semantics are intentionally not tied to one
execution engine; AbcDatalog, Nemo, Clingo, or another engine may later be used
behind an engine adapter after the refinement semantics and PAMoLa translation
boundary are validated.

The current EMR workload contains 56 requests (7 subjects × 4 records × 2
actions). Aggregate results such as 35/56 allowed are regression invariants
only. They are **not** treated as an independent correctness oracle.

## Build and test

Requirements:

- JDK 21+
- Maven 3.9+

Run:

```bash
mvn -B -ntp verify
```

The semantic regression tests pin down the existing legacy behavior before the
PAMoLa-aligned refactoring begins.

## Research contract

The approved scientific scope and evidence requirements are recorded in:

`docs/research-contract-pamola-v2.md`

Final manuscript claims must satisfy the evidence gates defined there.

## Important limitations

The current code is not yet the final research artifact. In particular, it does
not yet contain:

- a PAMoLa/HUTN importer;
- the validated canonical graph representation;
- an independent 56-request decision/provenance oracle;
- canonical rule-identity-preserving provenance;
- the engine-independent adapter architecture;
- multi-domain, XACML, Auctoritas, or structural-scaling experiments.

The repeated-request volume loop retained in the legacy evaluation source must
not be interpreted as input-complexity scalability evidence.
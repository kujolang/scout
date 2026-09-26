# Scout next review — round 2 — 2026-09-25

The prior queue is complete. This list preserves the next evidence-backed enhancement
opportunities; none is a known release blocker.

## Next-session queue

1. **PERF-005 — Reduce collection and sorting cost.** Prototype chunked result
   accumulation or a runtime-supported mutable builder, then compare it against the
   route-hotspot receipt and full performance gate. Accept only byte-equivalent output
   with improvements outside measurement noise.
2. **QUAL-003 — Cover multiline and composed declarations.** Add explicit parser
   capabilities (or documented diagnostics) for multiline route declarations, dynamic
   prefixes, and framework router composition without weakening literal precision.
3. **PORT-002 — Exercise Windows boundary behavior.** Add Windows-native cases for
   junction/reparse-point containment, rooted metadata reads, concurrent publication,
   and resource-limit identifiers where the host permits them.
4. **REL-005 — Add release provenance.** Publish signed checksums or attestations for
   Scout release artifacts and verify them in the documented install path.
5. **UX-002 — Version structured diagnostics.** Add an opt-in JSON diagnostic stream
   with a schema version, code, category, message, and resource/limit fields while
   retaining human-readable default output.

## Acceptance evidence

- Full regression suite on the checksum-verified official Kujo release.
- Fast and full performance receipts with output-equivalence checks.
- Updated per-family labeled-analysis receipt.
- Hosted Linux and Windows jobs green after push.

Scout's claims remain deliberately corpus- and contract-scoped. New capabilities should
strengthen those contracts without implying complete static analysis of arbitrary code.

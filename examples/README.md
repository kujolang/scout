# Scout Examples

Copyable Scout usage examples live in the main repository README. This directory exists as a stable examples surface for release-readiness scanners.

```bash
kujo run scout.kujo -- . --quick
kujo run scout.kujo -- ./lib --skip-security --skip-routes -o ./results/lib-context
kujo run scout.kujo -- ./lib --security-export sarif --security-export jsonl -o ./results/security-audit
```

---
title: Establish executable validation contract for ingest Step 1 and complete the crystallize workflow
date: 2026-04-13
category: workflow-issues
module: llm-wiki
problem_type: workflow_issue
component: development_workflow
symptoms:
  - Step 1 JSON output only had textual conventions, no executable format validation gate.
  - When `confidence` is missing or incorrectly filled, Step 2 could still continue executing.
  - A legitimate empty `entities` array could be incorrectly flagged as failure if mishandled.
  - Users already need a “crystallize” entry point, but the repo had no corresponding workflow, template, or directory preparation.
root_cause: missing_validation
resolution_type: workflow_improvement
severity: medium
related_components:
  - documentation
  - tooling
  - testing_framework
tags: [ingest, step1-validation, confidence-rules, crystallize, regression]
---

# Establish executable validation contract for ingest Step 1 and complete the crystallize workflow

## Problem
The `ingest` two-step flow originally only had documentation, no actually executing Step 1 validation gate, so “whether the output structure qualifies” could only rely on conventions. Meanwhile, `crystallize` was already a clear requirement, but the repo had no corresponding routing, template, or persistence conventions.

## Symptoms
- Although `SKILL.md` described Step 1's JSON structure and confidence rules, no script would intercept bad output before Step 2.
- When the `confidence` field was missing or set to an illegal value, the flow lacked a unified failure exit.
- Some inputs naturally don't yield entities; an empty `entities` array should be a legitimate result, but overly strict validation logic would incorrectly reject it.
- When users said “crystallize,” the system had no dedicated workflow, no `wiki/synthesis/sessions/` template, and no directory preparation.

## What Didn't Work
- Only writing rules in [`SKILL.md`](../../SKILL.md) wasn't enough; text won't automatically prevent bad JSON from entering Step 2.
- Only checking if `entities` exists wasn't enough either, because it would miss missing `confidence` and illegal value issues.
- Directly iterating `.entities[]` was too fragile. An empty array is legitimate, but this approach easily conflates “no entities” with failure in shell pipelines.
- Adding just a `crystallize` documentation section wasn't enough; without templates, directories, and initialization support, this workflow still couldn't land.

## Solution
Tightened this change into “documentation rules + executable script + regression tests” — all three layers working together.

The first layer is explicitly defining Step 1's confidence rules, validation steps, and `crystallize` routing and workflow in [`SKILL.md`](../../SKILL.md):

```text
EXTRACTED | INFERRED | AMBIGUOUS | UNVERIFIED
```

And requiring that after Step 1 completion, JSON must first be written to a temp file, then the validation script called:

```bash
mkdir -p {wiki_root}/.wiki-tmp
bash ${SKILL_DIR}/scripts/validate-step1.sh {wiki_root}/.wiki-tmp/step1-latest.json
```

The second layer is the new [`scripts/validate-step1.sh`](../../scripts/validate-step1.sh), turning rules into real execution gates. It now:
- Checks file arguments, `jq` dependency, and JSON validity
- Checks types of `entities`, `topics`, `connections`, `contradictions`, `new_vs_existing`
- Checks each entity's `confidence` can only be `EXTRACTED / INFERRED / AMBIGUOUS / UNVERIFIED`
- Allows empty `entities` arrays to pass, not incorrectly flagging legitimate empty results as errors

The most critical fix is:

```bash
INVALID=$(jq -r '.entities[]? | (.confidence // "MISSING")' "$JSON_FILE" 2>/dev/null | \
    grep -v -E "^(EXTRACTED|INFERRED|AMBIGUOUS|UNVERIFIED)$" | head -3)
```

Here `[]?` lets empty arrays pass silently, but if an entity is missing `confidence`, it's still caught as `MISSING`; if the value is an illegal one like `HIGH`, it's directly blocked.

The third layer completes `crystallize` into a truly executable workflow:
- [`templates/synthesis-template.md`](../../templates/synthesis-template.md) provides unified crystallization page structure
- [`scripts/init-wiki.sh`](../../scripts/init-wiki.sh) pre-creates `wiki/synthesis/sessions/`
- `.gitignore` is written during initialization to ignore `.wiki-tmp/`
- [`SKILL.md`](../../SKILL.md) adds `crystallize` routing and output examples

Finally, regression gates are added in [`tests/regression.sh`](../../tests/regression.sh) to lock script behavior, documentation rules, and initialization directories:
- No arguments should show usage
- Valid JSON should pass
- Missing `confidence` should fail
- Illegal `confidence` should fail
- `entities` not being an array should fail
- Empty `entities` array should pass
- `SKILL.md` must contain the new rules, validation steps, and `crystallize` workflow
- `init-wiki.sh` must create `wiki/synthesis/sessions/`

## Why This Works
It transforms previously “written in documentation” constraints into actually executable input contracts. Step 1 is no longer a loose intermediate state but a bounded gate: wrong structure triggers fallback, non-compliant confidence triggers fallback, and empty `entities` isn't incorrectly killed.

The `crystallize` line also went from “has requirements but no landing point” to a complete loop: users have trigger words, the repo has templates, initialization prepares directories, and logs have fixed recording locations. This way the workflow is no longer just a documentation promise but an actually implementable knowledge crystallization path.

## Prevention
- Whenever modifying Step 1 output format, must simultaneously check [`SKILL.md`](../../SKILL.md), [`scripts/validate-step1.sh`](../../scripts/validate-step1.sh), and [`tests/regression.sh`](../../tests/regression.sh); don't modify just one layer.
- For shell + `jq` array validation, default to considering whether empty arrays are legitimate first; if legitimate, avoid conflating “empty results” with “bad results” as the same failure class.
- When adding workflows, don't just add routing documentation; also add templates, initialization directories, and regression gates, otherwise the flow stops at “documented but can't run.”
- The minimum verification gate after completing this kind of work should at least include:

```bash
bash tests/regression.sh
```

- If Step 1 JSON fields are extended later, add failure test cases first, then modify scripts and documentation, ensuring new fields don't exist only in documentation without execution constraints.

## Related Issues
- Related but non-duplicate workflow hardening doc: [`freeze-ingest-source-contract-and-registry-2026-04-06.md`](../developer-experience/freeze-ingest-source-contract-and-registry-2026-04-06.md)
- Adapter state governance in the same ingest domain: [`unify-optional-adapter-states-and-fallback-paths-2026-04-06.md`](../integration-issues/unify-optional-adapter-states-and-fallback-paths-2026-04-06.md)
- Adjacent compatibility work: [`legacy-wiki-lazy-compatibility-2026-04-06.md`](legacy-wiki-lazy-compatibility-2026-04-06.md)
- GitHub issue search: `gh issue list --search "ingest validation confidence crystallize" --state all --limit 5` found no directly matching issues

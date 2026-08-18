# srr statistical-standards compliance -- working notes

Status: **tagging complete; 0 test failures; awaiting maintainer review
before PR.** Last updated: 2026-08-18.

Process documentation for kindling's srr compliance work
([ropensci/software-review#784](https://github.com/ropensci/software-review/issues/784),
action item 1 of
[maurolepore's 2026-08-17 comment](https://github.com/ropensci/software-review/issues/784#issuecomment-5319506850)),
kept deliberately reusable: @mpadge proposed deriving a second
[ropensci-skills](https://github.com/ropensci-review-tools/ropensci-skills)
SKILL.md ("a skill to actually insert the compliance statements",
[ropensci-skills#7](https://github.com/ropensci-review-tools/ropensci-skills/pull/7#issue-4909638056))
from exactly this kind of process. §6 is written as a draft of that
skill's method.

## 1. Inputs

- Categories: **general + ml** (chosen in the pre-submission thread; RE
  may be added later -- standards can span categories).
- Scaffolding (done by hand before this work started):
  `srr::srr_stats_roxygen(category = c("general", "ml"))` generating
  `R/srr-stats-standards.R` with 158 `@srrstatsTODO` tags (68 G + 90 ML),
  and the `Roxygen:` roclets line in `DESCRIPTION`.
- References followed: [stats-devguide §3.5](https://stats-devguide.ropensci.org/pkgdev.html#pkgdev-srr)
  and the [srr vignette](https://docs.ropensci.org/srr/articles/srr-stats.html).
- Starting point: @mpadge's AI-generated feasibility assessment
  ([issuecomment-5001024813](https://github.com/ropensci/software-review/issues/784#issuecomment-5001024813)).
  Important nuance: its Y/N/NA verdicts measured *achievability*, not
  current compliance -- each standard was re-verified against the actual
  code before tagging (see §4 for where we deviated).
- Threshold (per mpadge): ≥ 50% of standards in General and in the chosen
  category; `@srrstatsNA` with justification excludes a standard from the
  denominator under rOpenSci's applicable-standards convention. 100% was
  explicitly not the goal.

## 2. Outcome

| category | `@srrstats` | `@srrstatsNA` | `@srrstatsTODO` | compliance (excl. NA) |
|---|---|---|---|---|
| General (68) | 55 | 12 | 1 | 55/56 = **98%** |
| ML (90) | 51 | 30 | 9 | 51/60 = **85%** |

Both far above the 50% bar. Verified with `devtools::document()` (srr
roclet output lists every standard exactly once across the three tag
kinds; a diff against the generated category lists confirmed no invented
IDs and no cross-kind duplicates).

Remaining `@srrstatsTODO` (substantial development, listed for
discussion, in `R/srr-stats-standards.R`):

- **G5.2b** -- tests for *every* individual message (principal error
  conditions are tested; exhaustive per-message coverage is not).
- **ML3.1** -- warm-start/pre-trained model re-use (depends on ML5.2c).
- **ML4.1, ML4.1a, ML4.1c** -- full optimizer-path retention (parameter
  snapshots, gradient info); only per-epoch loss (ML4.1b) is retained.
- **ML5.2b, ML5.2c** -- torch-safe `save`/`load` functions
  (`saveRDS()` breaks on external pointers) + their documentation. The
  most user-valuable TODO; flagged by mpadge's assessment as a priority.
- **ML7.3, ML7.3a, ML7.3b** -- *tests* comparing model-object
  functionality against other packages' classes (currently documentation
  only, in `vignette("similar-packages")`).

## 3. What was implemented (minor changes only, per the agreed rule)

- **`R/checks-input.R`** (new): `check_training_args()` (scalar
  length/type/range assertions for `epochs`, `batch_size`, `learn_rate`,
  `validation_split`, `verbose`, `cache_weights`),
  `check_predictor_matrix()` / `check_outcome()` (zero-row, non-numeric,
  `NA`, `NaN`/`Inf`, length-mismatch guards), `check_newdata_matrix()`
  (same missing-value policy at predict time). All errors carry class
  `kindling_input_error`. Wired into `train_nn_impl()`, `ffnn_impl()`,
  `rnn_impl()`, `train_nn_impl_dataset()` and `predict.nn_fit()`.
  Covers G2.0-2.2, G2.13-2.16, G5.8a/b, ML1.6, ML1.8.
  (Pitfall found: assertions must run *before* the first `if (verbose)`
  use, otherwise `verbose = "yes"` crashes before being validated --
  caught by the new tests.)
- **Diagnostic messages (G2.9)**: `cli_inform()` when predictor names are
  auto-generated and when a character outcome is coerced to factor.
- **Documentation additions** to `?train_nn`: sections "Training,
  validation, and test data" (ML1.0/ML1.0a/ML6.0 + ordered-factor note
  for G2.5), "Missing values" (why NAs error + recipes imputation example
  -- ML1.6a/b), "Learning rate, batch size, and epochs"
  (ML3.4/3.4a/3.4b, ML4.4).
- **Life Cycle Statement** in `.github/CONTRIBUTING.md` (G1.2).
- **`vignette("tuning-capabilities")`**: pointer to custom yardstick
  metrics via `metric_set()` (ML5.4b).
- **New tests**: `test-srr-input-checks.R` (32 assertions: G5.8 family,
  G2.11 difftime column, G2.12 list column, all guards, G2.9 messages),
  `test-srr-correctness.R` (linear-model parameter recovery vs `lm()`
  with fixed seeds and tolerances -- G5.4/4b/5/6/6a; loss decrease and
  early-stop threshold behaviour -- G5.7/ML7.6; eps-noise and seed
  robustness -- G5.9a/b; divergence under lr=100 -- ML7.4;
  `expand.grid()` architecture x optimizer combinations -- ML7.9/9a/10),
  `test-srr-extended.R` (multi-seed recovery gated by
  `KINDLING_EXTENDED_TESTS=true` -- G5.10/G5.6b), plus a
  multi-metric model-comparison test in `test-yardstick-integration.R`
  (ML7.11a). `tests/README.md` documents the extended suite (G5.12).

## 4. Where we deviated from mpadge's feasibility assessment

All deviations move Y-feasible → NA with an explicit justification (his
document itself notes NA calls were "this document's own estimates"):

- **G1.5, G1.6** → NA: no performance claims exist in any publication;
  the similar-packages comparison is feature-based.
- **G2.14b, G2.14c** → NA: ignore-with-warning and imputation are
  delegated to recipes/tidyr (same delegation pattern he accepted for
  ML2); within kindling, missing data errors (G2.14a implemented).
- **ML1.5** → NA: data-set summary tooling delegated to general R tools;
  kindling's print methods summarise the model.
- **ML4.5** → NA: optional standard ("may"), not implemented.
- **ML4.6** → NA as justified deviation: progress is opt-in
  (`verbose = TRUE`) following tidymodels' quiet-by-default convention.
- **ML5.4a** → NA: no internal metric functions exist (all yardstick).
- **ML7.0, ML7.1** → NA for consistency with the ML1.1-1.4 and ML2 NAs
  he assigned (no labels to test, no internal transformations to test).
  His table had counted these as feasible, which is inconsistent with
  those NAs.

And one correction in the other direction: his ML "zero N" framing hid
real *current* gaps -- those are now explicit TODOs (§2) instead of
being silently tagged compliant.

## 5. Tag-placement conventions used

- Standards addressed **in code** → `@srrstats` in the roxygen block of
  the implementing function (validators, impls, print/plot methods,
  parsnip constructors).
- Standards addressed **by tests** → tags at the top of the relevant
  test file (no `@noRd`/`NULL` needed in `tests/`).
- Standards addressed **in documentation/vignettes or via the documented
  tidymodels delegation** → central block in `R/srr-stats-standards.R`
  with explicit pointers to the file that holds the evidence (keeps
  vignettes free of srr chunks and README.Rmd un-reknitted).
- All `@srrstatsNA` in the single `NA_standards` block; all remaining
  `@srrstatsTODO` in a `TODO_standards` block with one-line rationales.

## 6. Reusable procedure (draft input for the ropensci-skills SKILL.md)

1. Scaffold: `srr_stats_roxygen(category = ...)` + `Roxygen:` roclets
   line; run `devtools::document()` once to confirm the roclet fires.
2. Read the whole `R/` and `tests/` tree first; build a per-standard
   decision table before touching any tag. Classify each standard:
   *met* / *NA with justification* / *met after minor change* (docs,
   assertions, small tests -- implement immediately) / *substantial*
   (leave TODO, list for humans; never silently implement features).
3. Prefer implementation-site tag placement (function roxygen, test
   headers); use one central block only for documentation-anchored and
   delegation-based standards, always with a pointer to the evidence.
4. Delegation to the surrounding ecosystem (recipes/rsample/yardstick
   for tidymodels packages) is a *legitimate* NA justification, but say
   *where* the delegated capability is documented/demonstrated.
5. Verify mechanically, not by eye: run the roclet, then diff the set of
   tagged IDs against the generated category lists (no invented IDs, no
   standard under two tag kinds, none missing) and compute the per-
   category tallies. (Here this caught one dropped standard, ML5.4a.)
6. Any new assertion layer must run before any use of the arguments it
   validates; add tests that pass invalid values for *every* asserted
   argument.
7. Keep new correctness tests deterministic (fixed R + torch seeds,
   `device = "cpu"`, generous tolerances) and cheap; push multi-seed
   variants behind an env-var-gated extended suite (G5.10) documented in
   `tests/README.md` (G5.12).
8. Finish with `devtools::document()`, the full test suite, and
   `R CMD check`; report failures honestly and fix before review.

## 7. Verification record

- `devtools::document()`: roclet lists 106 unique `@srrstats`, 42
  `@srrstatsNA`, 10 `@srrstatsTODO`; set-diff against category lists
  clean (158/158 covered, no duplicates).
- `devtools::test()`: **0 failures, 709 passing**, 1 skip (extended
  suite, off by default), 35 warnings (pre-existing `tput cols` warnings
  from `table_summary()` in non-terminal sessions -- unrelated).
- Extended suite run once with `KINDLING_EXTENDED_TESTS=true`: 6/6 pass.
- `R CMD check --no-manual`: **0 errors, 0 warnings, 0 notes** (5m17s,
  macOS arm64, R 4.5, torch 0.16.3 with MPS available; correctness tests
  pin CPU).
- `srr::srr_stats_pre_submit()` is *expected to flag* the 10 remaining
  TODOs -- deliberate until the substantial items are discussed.

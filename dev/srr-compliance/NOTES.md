# srr statistical-standards compliance -- working notes

Status: **tagging complete, zero `@srrstatsTODO` remaining; awaiting
maintainer review before PR.** Last updated: 2026-08-18.

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
| General (68) | 56 | 12 | 0 | 56/56 = **100%** |
| ML (90) | 60 | 30 | 0 | 60/60 = **100%** |

Far above the 50% bar, and with **no TODO tags left**:
`srr::srr_stats_pre_submit()` passes cleanly, so the package is formally
submittable. Verified with `devtools::document()` (srr roclet) plus a
mechanical set-diff of tagged IDs against the generated category lists
(no invented IDs, no cross-kind duplicates, 158/158 covered).

The ten standards initially parked as TODO were all implemented rather
than NA'd -- none of them was honestly "not applicable", and an NA on
merely-unimplemented functionality would not survive review:

- **ML5.2c / ML5.2b** -- new `save_kindling()` / `load_kindling()`
  (`R/save-load.R`): `saveRDS()` cannot preserve torch external
  pointers, so the module is serialized via `torch::torch_serialize()`
  and the rest via R's serializer; round-trip documented and tested.
  (Pitfall found: reloaded recurrent modules carry stale internal
  `flat_weights_` tensor caches -> "external pointer is not valid" on
  forward; fixed by re-applying `$to(device = "cpu")` after load, which
  rebuilds the caches via `nn_rnn_base$.apply()`.)
- **ML3.1** -- warm start: `train_nn(initial_model = )` accepts a
  previously trained or reloaded `nn_fit`, deep-copies its module
  (serialize/load round-trip) so the source is untouched, inherits its
  architecture metadata, and validates dimension compatibility.
- **ML4.1 / ML4.1a / ML4.1c** -- `train_nn(track_optim_path = TRUE)`
  optionally retains a per-epoch `optim_path` data frame: loss value
  (ML4.1b), global gradient norm (ML4.1c), and a hash of all model
  parameters (ML4.1a, the standard's "equivalent hashed
  representation").
- **ML7.3 / ML7.3a / ML7.3b** -- `test-srr-model-comparison.R` compares
  kindling fit objects against `nnet::nnet` fits (recommended package,
  so the comparison always runs, unlike a brulee/cito Suggests-gated
  test): shared `predict()` ability, explicit restrictions (no
  `coef()`/`summary()`), explicit unique abilities (loss history,
  autoplot, torch-safe save/reload).
- **G5.2b** -- per-message test coverage, closed mechanically: run
  `covr::package_coverage(type = "tests")` and list every
  `cli_abort()`/`cli_warn()`/`cli_inform()`/`stop()` line with zero
  coverage; each such line is an untested message. Tests were then
  written for exactly that gap list (`test-srr-messages.R`), calling
  internal validators directly where the public API cannot reach them.

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

Second round (closing the last ten standards, see §2): `R/save-load.R`
(`save_kindling()`/`load_kindling()`), `initial_model` and
`track_optim_path` arguments on `train_nn()`, `test-srr-save-load.R`,
`test-srr-model-comparison.R` (nnet added to Suggests),
`test-srr-messages.R`, and a package-namespace `requireNamespace`
wrapper in `R/utils.R` so testthat can mock dependency-missing guards
(base bindings cannot be mocked directly; note it must be a *wrapper*
calling `base::requireNamespace`, not a copy of it -- copying embeds
base's `.Internal()` calls in package code and triggers an R CMD check
WARNING). Two genuine pre-existing
bugs surfaced and were fixed along the way: `autoplot_diagnostics()`
compared `length()` of a matrix `actual` against fitted rows, making
the documented multi-output diagnostics branch unreachable; and the
existing structure test had to learn the new `optim_path` component.

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
7bis. For per-message test coverage (G5.2b), don't audit by hand: run
   `covr::package_coverage(type = "tests")` and treat every
   zero-coverage `cli_abort()`/`cli_warn()`/`stop()` line as the exact
   list of untested messages; write tests for that list, calling
   internal validators directly (`pkg:::fn`) where the public API
   cannot reach a branch, and `testthat::local_mocked_bindings()` for
   guards that depend on absent dependencies.
8. Finish with `devtools::document()`, the full test suite, and
   `R CMD check`; report failures honestly and fix before review.

## 7. Verification record

- `devtools::document()`: roclet clean; set-diff of tagged IDs vs the
  category lists: **G 56 `@srrstats` / 12 `@srrstatsNA` / 0 TODO;
  ML 60 / 30 / 0** -- 158/158, no duplicates, no invented IDs.
- `srr::srr_stats_pre_submit()`: "All applicable standards have been
  documented in this package" with **no remaining TODO warning** -- the
  package is formally submittable.
- `devtools::test()`: **0 failures, 811 passing**, 1 skip (extended
  suite, off by default), 35 pre-existing `tput cols` warnings
  (unrelated). Extended suite passes with
  `KINDLING_EXTENDED_TESTS=true`.
- Test coverage 89.2% (`covr`), used mechanically to close G5.2b.
- `R CMD check --no-manual`: 0 errors, 0 warnings, 0 notes (macOS
  arm64; correctness tests pin CPU).

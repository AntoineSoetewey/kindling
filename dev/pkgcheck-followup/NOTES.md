# pkgcheck follow-up: `layer_prs` + goodpractice audit

Status: **fix ready, awaiting review.** Last updated: 2026-08-21.

Follows the check run of 2026-08-20
([issuecomment-5360332681](https://github.com/ropensci/software-review/issues/784#issuecomment-5360332681)),
where two previously-passing checks began failing, and audits the
`goodpractice` items maurolepore pointed at in
[issuecomment-5319506850](https://github.com/ropensci/software-review/issues/784#issuecomment-5319506850).

## 1. The regression (blocking, now fixed)

```
✖ The following function has no documented return value: [layer_prs]
✖ These functions do not have examples: [layer_prs].
```

**Cause: self-inflicted, in PR #37.** `layer_prs` documents five exported
*data objects* (`.layer`, `.i`, `.in`, `.out`, `.is_output`) — pronouns
used inside `layer_arg_fn` formulas, not functions. Running
`devtools::document()` with roxygen2 **8.1.0** (the srr work needed a
re-document; the package had been built with 7.3.3) stopped emitting
`\docType{data}` and `\format{}` for that topic. `man/layer_prs.Rd` was
the only file affected — `kindling.Rd` and `reexports.Rd` kept theirs.

Both pkgcheck checks exempt data objects, so losing the tag made a
data topic look like an undocumented function:

- `check-fns-have-return-vals.R`: fails when
  `!nzchar(docType) & !keyword %in% c("datasets","internal") & !nzchar(value)`
- `check-fns-have-exs.R`: drops rows where
  `docType %in% c("package", "data")` before testing for examples

**Fix**: restore `@docType data`, and add `@format` plus real
`@examples` showing the pronouns inside `layer_arg_fn` formulas (useful
in their own right — the pronouns are the least obvious part of the
generator API).

**Verified** by replicating both pkgcheck functions locally against all
46 `.Rd` files (`dev/pkgcheck-followup/verify-pkgcheck.R`): zero failures
after the fix, and the same script reproduces exactly the two reported
failures when pointed at the pre-fix `layer_prs.Rd` — so the replication
is faithful, not vacuously green.

**Lesson**: a roxygen2 major-version bump silently changes generated
`.Rd` semantics. When re-documenting under a new roxygen2, diff `man/`
and not just `NAMESPACE`. In PR #37 the NAMESPACE reformatting was
checked and reported; the `man/` diff was noted as "roxygen re-render"
without inspecting what changed inside it.

## 2. goodpractice audit

Run locally with `goodpractice::gp()`. Two fixed, the rest assessed:

| check | verdict |
|---|---|
| `description_pkgname_single_quoted` | **Fixed.** `workflows` and `recipes` were unquoted in `Description` while `'torch'`, `'tidymodels'`, `'parsnip'` were quoted. Now consistent; the check passes. |
| `complexity_unused_internal` | **Partly fixed.** `extract_param_bounds()` in `R/grid_depth.R` was genuinely dead (zero call sites in `R/` or `tests/`; not to be confused with the live `extract_param_range()`) — removed. The remaining hits are false positives: the `$.nn_fit` / `$.ffnn_fit` / `$.rnn_fit` / `$.layer_pr` S3 methods (dispatched, never called by name) and `%||%` (used 11× as an infix operator). |
| `rd_has_examples` | **layer_prs cleared.** Still flags `man/kindling-nn-wrappers.Rd`, which carries `\keyword{internal}` — pkgcheck exempts it, goodpractice does not. These are parsnip engine-glue functions; examples would be noise. Left. |
| `rd_has_return` | **Still flags `layer_prs`** — goodpractice, unlike pkgcheck, does not exempt `\docType{data}`. These are data objects, so `\format` (which they now have) is the semantically correct section, not `\value`. Left deliberately; the blocking pkgcheck gate passes. |
| `roxygen2_unknown_tags` | **False positive, unavoidable.** The unknown tags are `@srrstats` / `@srrstatsNA` / `@srrstatsVerbose` — the srr roclet tags rOpenSci itself requires. goodpractice's roxygen2 parse doesn't know the registered roclet. |
| `roxygen2_has_export_or_nord` | **Left, by rOpenSci's own guidance.** The 17 sites use `@keywords internal`, which standard **G1.4a** explicitly names as an accepted alternative to `@noRd` ("...or `@keywords internal` if documentation is still desired"). Switching them would also delete their `.Rd` files. |
| `roxygen2_duplicate_params` | **Real, deferred.** ~56 sites: `train_nn()`, `ffnn()`, `rnn()`, and the parsnip specs repeat identical `@param` text. `@inheritParams` would genuinely help, but it is a broad documentation refactor across the core API — better as its own PR than bundled with a regression fix. |
| `complexity_function_length`, cyclocomplexity | **Noted, not acted on.** `train_nn_impl()` has cyclocomplexity 109; `train_nn_impl_dataset()` 54; `ffnn_impl()` 43. Splitting the training core is a real refactor with real regression risk, and reviewers may prefer to weigh in first. |
| `tidyverse_*` linters | Already handled in PR #38 via `.lintr`; goodpractice runs its own linter set and ignores that config, which is why the bot still reports ~1300 lints (down from 1615). |

## 3. Note on the bot's lintr figure

The `.lintr` config added in PR #38 governs `lintr::lint_package()`, but
`goodpractice` applies its own hard-coded linter subset and does **not**
read `.lintr`. So the bot's count fell only from 1615 to 1304 (the
genuine cleanups), and the 793 `<-`-assignment and 468 line-length
entries it still reports are the house-style items the config records as
deliberate. This is worth stating plainly to the editor rather than
chasing the number.

# lintr cleanup -- working notes

Status: **done, awaiting review.** Last updated: 2026-08-18.

Action item 3 of [maurolepore's comment on ropensci/software-review#784](https://github.com/ropensci/software-review/issues/784#issuecomment-5319506850)
("*lintr found the following 1615 potential issues*. This is not a
requirement for submission but it's a great way to improve the package
so that eventually the reviewers can focus on the more interesting
aspects of kindling").

## Outcome

**6635 lints → 76**, and two real bugs found and fixed along the way.

| stage | lints | what changed |
|---|---|---|
| baseline (lintr defaults) | 6635 | — |
| after `.lintr` house-style config | 802 | 4-space indent + `=` assignment + 120-char lines |
| after mechanical fixes | 391 | trailing whitespace, brace layout |
| after final config + dead-code removal | **76** | see below |

(The editor's figure of 1615 comes from `goodpractice`'s own linter subset,
not the full default set; the shape of the problem is the same.)

## Method

The useful move was to separate **config mismatch** from **actual defects**
before touching any code. 5428 of the 6635 baseline lints -- 82% -- were
lintr's defaults disagreeing with deliberate, package-wide house style:

- `indentation_linter` expects 2 spaces; kindling uses 4 (4581 lints).
- `assignment_linter` expects `<-`; kindling uses `=` everywhere (847).

Neither is a defect, so both are recorded in `.lintr` rather than "fixed".
Everything documented in that file is a deliberate choice, with the
rationale inline.

## What was actually fixed

- **Trailing whitespace / blank lines** (418) in `R/`, `tests/testthat/`,
  and `inst/examples/`. Deliberately *not* applied to `.Rmd` files, where
  two trailing spaces are a meaningful markdown line break.
- **Brace layout** (10): `)` followed by `{` on its own line joined into
  `) {`.
- **`1:max(...)` → `seq_len(max(...))`** in `table_summary()` -- a latent
  bug: the descending sequence when the table is empty.
- **Dead `dots = list(...)`** assignments in `ffnn()` and `rnn()`.
- **Dead commented-out code** left over from two refactors that NEWS.md
  documents as complete (`do.call()` → `rlang::exec()`, `glue::glue()` →
  `sprintf()`/`paste0()`).
- Small items: infix spacing, compound semicolons, single quotes, and two
  over-long `cli` message strings refactored for readability.

### The real bug this surfaced

Reading the dead `glue::glue()` comments in `train_nn_impl()` exposed a
regression from that rewrite:

```r
msg = sprintf("Epoch %d/%d - Loss: %.4f", ...)
if (!is.null(val_loss_history))
    # msg = glue::glue("{msg} - Val Loss: ...")
    sprintf("Epoch {epoch}/{epochs} - Loss: {...}")   # computed, discarded
message(msg)
```

The validation branch built a string with leftover glue `{}` syntax
(inert in `sprintf()`) and **discarded it**, so `train_nn(verbose = TRUE)`
never printed validation loss -- unlike `ffnn()`/`rnn()`, which do it
correctly. Fixed to match, and verified by running a fit with
`validation_split = 0.2`.

This is the argument for treating `commented_code_linter` as signal
rather than noise: dead code left next to live code hides regressions in
the live code.

## What was deliberately left

76 remaining lints, all judgment calls rather than defects:

- `commented_code_linter` (30) -- remaining commented blocks document
  alternative approaches rather than being abandoned refactors. Author's
  call.
- `object_usage_linter` (20) -- false positives: lintr resolves globals
  against the *installed* kindling (0.3.2, predating `check_*()`,
  `.clone_nn_module()`), and cannot see through `cli`/glue interpolation
  (`{valid_params_str}`, `{best_ep}`) or the `local({fn = fn; ...})`
  closure idiom. These clear themselves once the new version is installed.
- `line_length_linter` (14) -- long `cli` message strings and citation
  lines in roxygen references; splitting them would hurt readability.
- `trailing_whitespace_linter` (9) -- all in `.Rmd` files (see above).
- `object_name_linter` (2) -- the `requireNamespace()` wrapper (named
  after the base function it wraps, deliberately) and the S3 method
  `vi_model.ffnn_fit`.

## Reusable lesson

For a package with an established personal style, run lintr once, sort by
linter, and check the top 2-3 categories against the code before fixing
anything: if a category is uniform across the whole package it is almost
certainly style, and belongs in `.lintr` with a written rationale. The
long tail is where the defects are -- and `commented_code_linter` in
particular is worth reading rather than silencing.

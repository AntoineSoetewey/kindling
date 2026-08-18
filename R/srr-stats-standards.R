#' srr_stats
#'
#' Standards addressed in documentation files or through kindling's
#' documented tidymodels workflow are grouped here with pointers to where
#' the evidence lives. Standards addressed directly in code carry their
#' `@srrstats` tags at the implementation site (see `R/checks-input.R`,
#' `R/generalized-nn-fit.R`, `R/gen-train-nn-parsnip.R`, print/plot
#' methods, and the `tests/testthat/test-srr-*.R` files).
#'
#' @srrstatsVerbose TRUE
#'
#' @srrstats {G1.1} `vignette("similar-packages")` documents that kindling
#'   is one of several R implementations of torch-based neural-network
#'   training (brulee, cito, luz) and states how it differs (code
#'   generation, architectural flexibility, three-level API).
#' @srrstats {G1.2} A Life Cycle Statement is included in
#'   `.github/CONTRIBUTING.md`; the README carries the matching repostatus
#'   "Active" badge.
#' @srrstats {G5.12} Conditions for running the extended test suite (the
#'   `KINDLING_EXTENDED_TESTS` environment variable, expected runtime) are
#'   described in `tests/README.md`.
#' @srrstats {ML3.3} `vignette("similar-packages")` explicitly compares
#'   kindling's model objects, design philosophy, and abilities/restrictions
#'   with brulee, cito, and luz.
#' @srrstats {ML4.7} Combining results over multiple re-sampling iterations
#'   is provided through the documented tune/rsample integration: a single
#'   parameter (`v` in `rsample::vfold_cv()`) controls iteration count, as
#'   demonstrated in `vignette("tuning-capabilities")`.
#' @srrstats {ML4.8} Re-sampling in the documented workflow partitions data
#'   according to the proportions given to `rsample` (e.g.
#'   `initial_split(prop = ...)`); kindling's own `validation_split`
#'   likewise partitions by the supplied proportion.
#' @srrstats {ML4.8a} Those default proportions are user-controllable
#'   (`prop`, `v`, `validation_split`).
#' @srrstats {ML5.1} `vignette("similar-packages")` compares the trained
#'   model objects and capabilities of kindling against brulee, cito, and
#'   luz, noting unique abilities and restrictions.
#' @srrstats {ML5.2} The structure of trained model objects is thoroughly
#'   documented: the Details section of `?train_nn` lists every component
#'   of an `nn_fit` object.
#' @srrstats {ML5.2a} All functionality extending from the fit classes is
#'   documented and cross-linked: `predict()`, `print()`, `plot()`/
#'   `autoplot()`, `autoplot_diagnostics()`, and `garson()`/`olden()`
#'   variable importance.
#' @srrstats {ML5.3} Performance assessment is implemented distinctly from
#'   training, via the documented yardstick integration
#'   (`parsnip::augment()` |> `yardstick::metrics()`), demonstrated in
#'   `vignette("kindling")` and tested in
#'   `tests/testthat/test-yardstick-integration.R`.
#' @srrstats {ML5.4} A variety of performance metrics is available through
#'   `yardstick::metric_set()`, as demonstrated in
#'   `vignette("tuning-capabilities")`.
#' @srrstats {ML5.4b} Custom metrics can be submitted through the same
#'   mechanism (`yardstick::new_numeric_metric()` passed to
#'   `metric_set()`), documented in `vignette("tuning-capabilities")`.
#' @srrstats {ML6.1} `vignette("kindling")` and
#'   `vignette("special-cases")` document how kindling embeds within a full
#'   ML workflow, with data partitioning, pre-processing, and evaluation
#'   handled by dedicated packages.
#' @srrstats {ML6.1a} Those workflow demonstrations embed kindling with
#'   more than two other packages: recipes, rsample, workflows, parsnip,
#'   tune, and yardstick.
#' @noRd
NULL

#' NA_standards
#'
#' @srrstatsNA {G1.5} No performance claims are made in any associated
#'   publication, so there is no code to reproduce them.
#' @srrstatsNA {G1.6} For the same reason there are no performance claims
#'   to compare against alternative implementations; the comparison with
#'   similar packages (`vignette("similar-packages")`) is feature-based.
#' @srrstatsNA {G2.14b} Ignoring missing data with a warning is
#'   deliberately not offered: torch tensors cannot represent `NA`, so
#'   kindling errors on missing values (G2.14a) and delegates
#'   omission/imputation to the pre-processing layer (recipes / tidyr),
#'   as documented in the "Missing values" section of `?train_nn`.
#' @srrstatsNA {G2.14c} Imputation is likewise delegated to
#'   `recipes::step_impute_*()` in the documented workflow rather than
#'   re-implemented internally.
#' @srrstatsNA {G3.1} kindling performs no covariance calculations.
#' @srrstatsNA {G3.1a} No covariance methods exist to document.
#' @srrstatsNA {G4.0} kindling has no functions that write output to local
#'   files.
#' @srrstatsNA {G5.1} No data sets are created within the package; tests
#'   rely on standard, generally available data (iris, mtcars,
#'   mlbench::Ionosphere) and on simulated data generated in the tests
#'   themselves with fixed seeds.
#' @srrstatsNA {G5.4a} kindling implements no novel algorithms: it wraps
#'   established neural-network training provided by torch, and its
#'   correctness tests compare against existing reference implementations
#'   (see G5.4b in `tests/testthat/test-srr-correctness.R`).
#' @srrstatsNA {G5.4c} Reference implementations are directly available in
#'   R (e.g. `stats::lm()`), so stored values from published papers are not
#'   needed.
#' @srrstatsNA {G5.11} The extended tests require no large data sets or
#'   other downloaded assets.
#' @srrstatsNA {G5.11a} No downloads occur in any test, so download-failure
#'   handling is not applicable.
#' @srrstatsNA {ML1.1} kindling deliberately does not use a labelled
#'   train/test input design: data partitioning is delegated to
#'   rsample/tune per tidymodels convention, and kindling's own
#'   `validation_split` is proportion-based. This design choice is
#'   documented and justified under ML1.0a in `?train_nn`.
#' @srrstatsNA {ML1.1a} No train/test labels exist to confirm in
#'   pre-processing (see ML1.1).
#' @srrstatsNA {ML1.1b} No label matching exists (see ML1.1).
#' @srrstatsNA {ML1.2} Single-object train/test input with an indicator
#'   variable is not part of the design (see ML1.1); partitioning happens
#'   upstream in rsample.
#' @srrstatsNA {ML1.3} Partitioned multi-component input is not part of the
#'   design (see ML1.1).
#' @srrstatsNA {ML1.4} kindling reads no data from files or directories,
#'   so labelled storage sub-directories are not applicable.
#' @srrstatsNA {ML1.5} Data-summary tooling is delegated to general R
#'   tools (`summary()`, skimr, recipes); kindling functions only receive
#'   data at fit time and summarise the *model* (not the data sets) via
#'   their print methods.
#' @srrstatsNA {ML1.7} kindling does not admit missing values (they error
#'   informatively; see ML1.6), so there is no internal missing-value
#'   processing to document.
#' @srrstatsNA {ML1.7a} No internal imputation exists (see ML1.7).
#' @srrstatsNA {ML1.7b} No internal imputation steps exist to document
#'   (see ML1.7).
#' @srrstatsNA {ML2.0} Pre-processing is deliberately and wholly delegated
#'   to recipes in the documented workflow (`vignette("kindling")`,
#'   `vignette("special-cases")`): `recipes::recipe()` is the dedicated,
#'   parametrizable pre-processing function, and kindling applies no
#'   internal default transformations of its own.
#' @srrstatsNA {ML2.0a} The recipe object is directly usable in a
#'   `workflows::workflow()` together with a kindling model specification
#'   (see ML2.0).
#' @srrstatsNA {ML2.0b} Recipe objects carry their own print method
#'   summarising data and transformations (see ML2.0).
#' @srrstatsNA {ML2.1} kindling performs no broadcasting of dimensionally
#'   incommensurate inputs.
#' @srrstatsNA {ML2.2} kindling applies no internal numeric
#'   transformations; target values for transformations are specified in
#'   recipes steps (see ML2.0).
#' @srrstatsNA {ML2.2a} No internal transformation defaults exist (see
#'   ML2.2).
#' @srrstatsNA {ML2.2b} Transformation values are documented in the
#'   recipes ecosystem (see ML2.2).
#' @srrstatsNA {ML2.3} No internal transformations exist whose values
#'   could be recorded (see ML2.2).
#' @srrstatsNA {ML2.4} No internal default transformations exist to
#'   document (see ML2.2).
#' @srrstatsNA {ML2.5} There are no default transformations to bypass:
#'   kindling never transforms input values (see ML2.2).
#' @srrstatsNA {ML2.6} No internal transformation functions exist to
#'   export (see ML2.2).
#' @srrstatsNA {ML2.7} No internal transformations exist to reverse;
#'   reversal of recipes transformations is documented in the recipes
#'   ecosystem (see ML2.2).
#' @srrstatsNA {ML3.7} kindling contains no C++ code; all computation,
#'   including CPU/GPU dispatch, is delegated to torch.
#' @srrstatsNA {ML5.4a} kindling implements no performance-metric functions
#'   internally: all metrics come from yardstick, where each is documented;
#'   see ML5.4.
#' @srrstatsNA {ML4.5} Optional standard not implemented: training-time
#'   estimation is not offered; `verbose = TRUE` provides live progress
#'   information instead.
#' @srrstatsNA {ML4.6} Justified deviation: batch progress is opt-in
#'   (`verbose = TRUE`) rather than on-by-default, following the
#'   tidymodels quiet-by-default convention so that tuning loops (many
#'   fits) are not flooded with output. Enabling/suppressing progress is a
#'   single documented parameter.
#' @srrstatsNA {ML7.0} There is no train/test labelling scheme to test
#'   (see ML1.1).
#' @srrstatsNA {ML7.1} There are no internal numeric transformations whose
#'   scaling effects could be tested (see ML2.2); scaling is a recipes
#'   step.
#' @srrstatsNA {ML7.2} No internal imputation exists to test (missing
#'   values error; see ML1.7).
#' @srrstatsNA {ML7.5} No internal routine determines optimal training
#'   rates (see ML3.4a); the adaptive optimizers are torch's own,
#'   tested upstream.
#' @noRd
NULL

#' TODO_standards
#'
#' Standards not yet addressed: each needs substantial development and is
#' tracked for discussion with reviewers rather than silently implemented.
#'
#' @srrstatsTODO {G5.2b} Exhaustive per-message tests: the principal error
#'   conditions are tested (see `test-srr-input-checks.R` and existing
#'   suites), but not yet every individual message emitted by the package.
#' @srrstatsTODO {ML3.1} Re-use of pre-trained model objects (warm-start
#'   submission of a previously trained model) is not yet supported;
#'   depends on the save/load work under ML5.2c.
#' @srrstatsTODO {ML4.1} Optional retention of full optimizer paths is
#'   currently limited to per-epoch loss values (ML4.1b): parameter
#'   snapshots and gradient information are not yet retained.
#' @srrstatsTODO {ML4.1a} Per-step model-internal parameter retention not
#'   yet implemented (see ML4.1).
#' @srrstatsTODO {ML4.1c} Gradient/advance information retention not yet
#'   implemented (see ML4.1).
#' @srrstatsTODO {ML5.2b} Documentation of saving/re-loading trained
#'   models awaits the dedicated save/load functions (ML5.2c).
#' @srrstatsTODO {ML5.2c} `saveRDS()` is not appropriate for torch-backed
#'   fits (external pointers); dedicated `save`/`load` functions wrapping
#'   `torch::torch_save()`/`torch_load()` are planned.
#' @srrstatsTODO {ML7.3} Tests explicitly comparing kindling model-object
#'   functionality against equivalent classes from other ML packages are
#'   not yet implemented (the comparison currently lives in
#'   `vignette("similar-packages")` as documentation, not tests).
#' @srrstatsTODO {ML7.3a} See ML7.3.
#' @srrstatsTODO {ML7.3b} See ML7.3.
#' @noRd
NULL

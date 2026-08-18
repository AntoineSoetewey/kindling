#' @importFrom stats reorder setNames
#' @importFrom rlang :=
#' @importFrom lifecycle badge
#' @importFrom ggplot2 autoplot
NULL

# To avoid R CMD check notes about undefined global variables
utils::globalVariables(c(
    "x_names", "rel_imp", "object", "new_data", "nn_module", "fit_class",
    "epoch", "loss", "set",
    "fitted_val", "residuals", "actual_val",
    "actual", "predicted", "n", "prop"
))

has_namespace = function(pkg) {
    requireNamespace(pkg, quietly = TRUE)
}

# Package-namespace wrapper for the base function, so tests can mock
# dependency-missing guards via testthat::local_mocked_bindings()
# (base bindings themselves cannot be mocked). A wrapper, not a copy:
# copying would embed base's .Internal() calls in package code.
requireNamespace = function(package, ..., quietly = FALSE) {
    base::requireNamespace(package, ..., quietly = quietly)
}

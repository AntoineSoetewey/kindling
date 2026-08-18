#' Shared input assertions for kindling training functions
#'
#' Internal helpers called by `train_nn_impl()`, `ffnn_impl()`, and
#' `rnn_impl()` before any data reaches torch. All failures signal a
#' condition of class `"kindling_input_error"` with an informative message.
#'
#' @srrstats {G2.0} Scalar control parameters (`epochs`, `batch_size`,
#'   `learn_rate`, `validation_split`, `verbose`, `cache_weights`) are
#'   asserted to be single values before use.
#' @srrstats {G2.1} The same assertions check types: numeric for the numeric
#'   control parameters, logical for flags, numeric matrix for predictors.
#' @srrstats {G2.2} Multivariate input to univariate parameters is rejected
#'   by the `length(x) != 1L` assertions in `check_scalar_number()` and
#'   `check_flag()`.
#' @srrstats {G2.6} One-dimensional outcome input is accepted as bare
#'   vectors, factors, or single-column structures; `check_outcome()`
#'   validates it after class-independent pre-processing in the callers
#'   (`as.numeric()` / `as.integer()` encoding).
#' @srrstats {G2.13} `check_predictor_matrix()` and `check_outcome()` check
#'   for missing values before data is passed to any torch routine, and
#'   error informatively.
#' @srrstats {G2.14} Missing values in training data are an error by design
#'   (see `@srrstatsNA {G2.14b}` and `{G2.14c}`): torch tensors cannot carry
#'   `NA`, so kindling requires complete data and directs users to the
#'   recipes-based imputation/omission steps of its documented workflow.
#' @srrstats {G2.14a} The implemented option is "error on missing data",
#'   with a message naming imputation alternatives.
#' @srrstats {G2.15} Because missingness is rejected here at the boundary,
#'   no internal routine operates on data with potential `NA`s.
#' @srrstats {G2.16} Undefined values (`NaN`, `Inf`, `-Inf`) are likewise
#'   rejected with a dedicated message.
#' @srrstats {G5.8a} Zero-length (zero-row) data errors informatively.
#' @srrstats {G5.8b} Data of unsupported type (e.g. character predictors)
#'   errors informatively rather than reaching torch.
#' @srrstats {ML1.6} Missing values are detected in explicit pre-processing
#'   checks and produce informative errors (kindling does not admit them).
#'
#' @noRd
NULL

#' @noRd
check_scalar_number = function(x, arg, min = -Inf, max = Inf,
                               integerish = FALSE, max_open = FALSE) {
    if (!is.numeric(x) || length(x) != 1L || !is.finite(x)) {
        cli::cli_abort(
            "{.arg {arg}} must be a single finite number, not {.obj_type_friendly {x}}.",
            class = "kindling_input_error"
        )
    }
    if (integerish && x != trunc(x)) {
        cli::cli_abort(
            "{.arg {arg}} must be a whole number, not {.val {x}}.",
            class = "kindling_input_error"
        )
    }
    too_high = if (max_open) x >= max else x > max
    if (x < min || too_high) {
        upper = if (!is.finite(max)) {
            ""
        } else if (max_open) {
            paste0(" and below ", max)
        } else {
            paste0(" and at most ", max)
        }
        cli::cli_abort(
            "{.arg {arg}} must be at least {.val {min}}{upper}, not {.val {x}}.",
            class = "kindling_input_error"
        )
    }
    invisible(x)
}

#' @noRd
check_flag = function(x, arg) {
    if (!is.logical(x) || length(x) != 1L || is.na(x)) {
        cli::cli_abort(
            "{.arg {arg}} must be {.val {TRUE}} or {.val {FALSE}}.",
            class = "kindling_input_error"
        )
    }
    invisible(x)
}

#' Validate scalar training control parameters
#' @noRd
check_training_args = function(epochs, batch_size, learn_rate,
                               validation_split, verbose, cache_weights) {
    check_scalar_number(epochs, "epochs", min = 1, integerish = TRUE)
    check_scalar_number(batch_size, "batch_size", min = 1, integerish = TRUE)
    check_scalar_number(learn_rate, "learn_rate", min = .Machine$double.xmin)
    check_scalar_number(validation_split, "validation_split",
                        min = 0, max = 1, max_open = TRUE)
    check_flag(verbose, "verbose")
    check_flag(cache_weights, "cache_weights")
    invisible(NULL)
}

#' Validate the predictor matrix before it reaches torch
#' @noRd
check_predictor_matrix = function(x) {
    if (nrow(x) == 0L) {
        cli::cli_abort(
            "{.arg x} has no rows: training requires at least one observation.",
            class = "kindling_input_error"
        )
    }
    if (!is.numeric(x)) {
        cli::cli_abort(c(
            "{.arg x} must be numeric after pre-processing, not {.cls {typeof(x)}}.",
            i = "Encode non-numeric predictors first, e.g. with {.fn recipes::step_dummy} or {.fn hardhat::mold}."
        ), class = "kindling_input_error")
    }
    if (anyNA(x)) {
        cli::cli_abort(c(
            "{.arg x} contains missing values, which kindling models cannot be trained on.",
            i = "Impute them (e.g. {.fn recipes::step_impute_mean}) or drop incomplete rows (e.g. {.fn tidyr::drop_na}) before fitting."
        ), class = "kindling_input_error")
    }
    if (any(!is.finite(x))) {
        cli::cli_abort(
            "{.arg x} contains non-finite values ({.val NaN}, {.val Inf}): clean these before fitting.",
            class = "kindling_input_error"
        )
    }
    invisible(x)
}

#' Validate the outcome before encoding
#' @noRd
check_outcome = function(y, n_obs) {
    n_y = if (is.matrix(y)) nrow(y) else length(y)
    if (n_y != n_obs) {
        cli::cli_abort(
            "{.arg y} has {n_y} observation{?s} but {.arg x} has {n_obs} row{?s}: they must match.",
            class = "kindling_input_error"
        )
    }
    if (anyNA(y)) {
        cli::cli_abort(c(
            "{.arg y} contains missing values, which kindling models cannot be trained on.",
            i = "Impute or drop incomplete observations before fitting."
        ), class = "kindling_input_error")
    }
    if (is.numeric(y) && any(!is.finite(y))) {
        cli::cli_abort(
            "{.arg y} contains non-finite values ({.val NaN}, {.val Inf}): clean these before fitting.",
            class = "kindling_input_error"
        )
    }
    invisible(y)
}

#' Validate prediction input for missingness
#'
#' @srrstats {ML1.8} Missing values receive equal treatment in training and
#'   prediction: the same rejection rule is applied to `newdata` here as to
#'   training data in `check_predictor_matrix()`.
#' @noRd
check_newdata_matrix = function(newdata) {
    if (!is.numeric(newdata)) {
        cli::cli_abort(c(
            "{.arg newdata} must be numeric after pre-processing, not {.cls {typeof(newdata)}}.",
            i = "Supply the same predictor columns used during training."
        ), class = "kindling_input_error")
    }
    if (anyNA(newdata) || any(!is.finite(newdata))) {
        cli::cli_abort(
            "{.arg newdata} contains missing or non-finite values: kindling models cannot predict on them.",
            class = "kindling_input_error"
        )
    }
    invisible(newdata)
}

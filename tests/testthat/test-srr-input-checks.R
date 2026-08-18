#' @srrstats {G5.2} Error and warning behaviour of the input-validation
#'   layer is explicitly demonstrated by the tests in this file (together
#'   with the error-condition tests spread through the other test files).
#' @srrstats {G5.2a} All validation failures signal the dedicated condition
#'   class `kindling_input_error` with distinct, unique messages.
#' @srrstats {G5.8} Edge-condition tests below cover the standard's four
#'   named cases.
#' @srrstats {G5.8a} Zero-row data errors informatively.
#' @srrstats {G5.8b} Unsupported predictor types error informatively.
#' @srrstats {G5.8c} All-`NA` columns error informatively; all-identical
#'   columns train without error.
#' @srrstats {G5.8d} Data with more columns than rows trains without error.
#' @srrstats {G2.11} Data-frame columns with non-standard class attributes
#'   but numeric underlying data (here `difftime`) are processed without
#'   unreasoned errors.
#' @srrstats {G2.12} List columns produce an informative error during
#'   pre-processing rather than silent misbehaviour.
#' @srrstats {G2.13} Missing-value detection is tested for predictors and
#'   outcomes across `train_nn()`, `ffnn()`, and `rnn()`.
#' @srrstats {G2.16} Rejection of undefined values (`NaN`, `Inf`) is
#'   tested for predictors and outcomes.
#' @srrstats {ML1.6} The informative missing-value errors are exercised on
#'   both training interfaces.
#' @srrstats {ML1.8} Equal treatment of missing values at prediction time
#'   is tested (`predict()` rejects `NA` in `newdata` like training does).

skip_if_no_torch = function() {
    skip_if_not_installed("torch")
    skip_if_not(torch::torch_is_installed(), "Torch backend not available")
}

x_ok = matrix(rnorm(40), ncol = 2, dimnames = list(NULL, c("a", "b")))
y_ok = rnorm(20)

test_that("zero-row data errors informatively", {
    skip_if_no_torch()
    expect_error(
        train_nn(matrix(numeric(0), ncol = 2), numeric(0), epochs = 2),
        class = "kindling_input_error"
    )
})

test_that("non-numeric predictors error informatively", {
    skip_if_no_torch()
    x_chr = matrix(letters[1:6], ncol = 2)
    expect_error(
        train_nn(x_chr, 1:3, epochs = 2),
        class = "kindling_input_error"
    )
})

test_that("missing and non-finite predictor values error informatively", {
    skip_if_no_torch()
    for (bad in list(NA_real_, NaN, Inf, -Inf)) {
        x_bad = x_ok
        x_bad[3, 1] = bad
        expect_error(
            train_nn(x_bad, y_ok, epochs = 2),
            class = "kindling_input_error"
        )
    }
})

test_that("missing and non-finite outcome values error informatively", {
    skip_if_no_torch()
    for (bad in list(NA_real_, NaN, Inf)) {
        y_bad = y_ok
        y_bad[5] = bad
        expect_error(
            train_nn(x_ok, y_bad, epochs = 2),
            class = "kindling_input_error"
        )
    }
    y_fac = factor(rep(c("u", "v"), 10))
    y_fac[2] = NA
    expect_error(
        train_nn(x_ok, y_fac, epochs = 2),
        class = "kindling_input_error"
    )
})

test_that("outcome length mismatch errors informatively", {
    skip_if_no_torch()
    expect_error(
        train_nn(x_ok, y_ok[-1], epochs = 2),
        class = "kindling_input_error"
    )
})

test_that("ffnn and rnn share the same missing-value guards", {
    skip_if_no_torch()
    d = data.frame(a = rnorm(20), b = rnorm(20), y = rnorm(20))
    d_na = d
    d_na$a[4] = NA
    expect_error(
        ffnn(y ~ ., data = d_na, hidden_neurons = 4, epochs = 2),
        class = "kindling_input_error"
    )
    expect_error(
        rnn(y ~ ., data = d_na, hidden_neurons = 4, epochs = 2),
        class = "kindling_input_error"
    )
})

test_that("scalar control parameters are validated for length, type, and range", {
    skip_if_no_torch()
    expect_error(train_nn(x_ok, y_ok, epochs = c(5, 10)), class = "kindling_input_error")
    expect_error(train_nn(x_ok, y_ok, epochs = 2.5), class = "kindling_input_error")
    expect_error(train_nn(x_ok, y_ok, epochs = 0), class = "kindling_input_error")
    expect_error(train_nn(x_ok, y_ok, epochs = 5, batch_size = 0), class = "kindling_input_error")
    expect_error(train_nn(x_ok, y_ok, epochs = 5, learn_rate = 0), class = "kindling_input_error")
    expect_error(train_nn(x_ok, y_ok, epochs = 5, learn_rate = -1), class = "kindling_input_error")
    expect_error(train_nn(x_ok, y_ok, epochs = 5, validation_split = 1), class = "kindling_input_error")
    expect_error(train_nn(x_ok, y_ok, epochs = 5, validation_split = -0.1), class = "kindling_input_error")
    expect_error(train_nn(x_ok, y_ok, epochs = 5, verbose = "yes"), class = "kindling_input_error")
    expect_error(train_nn(x_ok, y_ok, epochs = 5, cache_weights = NA), class = "kindling_input_error")
})

test_that("all-NA columns error; all-identical columns train", {
    skip_if_no_torch()
    x_na_col = x_ok
    x_na_col[, 2] = NA_real_
    expect_error(
        train_nn(x_na_col, y_ok, epochs = 2),
        class = "kindling_input_error"
    )

    x_const = cbind(x_ok, c = 1)
    fit = train_nn(x_const, y_ok, epochs = 2)
    expect_s3_class(fit, "nn_fit")
})

test_that("data with more columns than rows trains", {
    skip_if_no_torch()
    x_wide = matrix(rnorm(40), nrow = 4, dimnames = list(NULL, paste0("v", 1:10)))
    fit = train_nn(x_wide, rnorm(4), epochs = 2, batch_size = 4)
    expect_s3_class(fit, "nn_fit")
})

test_that("columns with non-standard class attributes are processed (G2.11)", {
    skip_if_no_torch()
    d = data.frame(y = rnorm(20), a = rnorm(20))
    d$dur = as.difftime(runif(20, 1, 60), units = "mins")
    fit = train_nn(y ~ a + dur, data = d, epochs = 2)
    expect_s3_class(fit, "nn_fit")
    expect_true("dur" %in% fit$feature_names)
})

test_that("list columns error informatively during pre-processing (G2.12)", {
    skip_if_no_torch()
    d = data.frame(y = rnorm(10), a = rnorm(10))
    d$lst = replicate(10, list(1:3), simplify = FALSE)
    expect_error(train_nn(y ~ ., data = d, epochs = 2))
})

test_that("diagnostic messages are issued for name generation and outcome coercion (G2.9)", {
    skip_if_no_torch()
    x_unnamed = matrix(rnorm(40), ncol = 2)
    expect_message(
        train_nn(x_unnamed, y_ok, epochs = 2),
        "column names"
    )
    y_chr = rep(c("u", "v"), 10)
    expect_message(
        train_nn(x_ok, y_chr, epochs = 2),
        "converted to factor"
    )
})

test_that("predict rejects missing values in newdata like training does (ML1.8)", {
    skip_if_no_torch()
    fit = train_nn(x_ok, y_ok, epochs = 2)
    x_new = x_ok[1:5, , drop = FALSE]
    x_new[2, 1] = NA
    expect_error(
        predict(fit, newdata = x_new),
        class = "kindling_input_error"
    )
})

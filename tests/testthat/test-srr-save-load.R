#' @srrstats {ML5.2c} The dedicated save/load functions are round-trip
#'   tested: saveRDS alone cannot preserve torch external pointers, so
#'   save_kindling()/load_kindling() are verified to restore a fully
#'   functional model with identical predictions.
#' @srrstats {ML5.2b} Saving, re-loading, and re-using models (including
#'   re-submission to train_nn() via initial_model) is tested end to end.
#' @srrstats {ML3.1} Warm-starting from previously trained and from
#'   reloaded models is tested: training continues from the supplied
#'   weights (initial loss near the previous final loss) and leaves the
#'   supplied object untouched.
#' @srrstats {ML4.1} Optional optimizer-path retention is tested below.
#' @srrstats {ML4.1a} `optim_path$param_hash` changes across epochs while
#'   training advances.
#' @srrstats {ML4.1c} `optim_path$grad_norm` is finite and positive while
#'   training advances.
#' @srrstats {ML7.10} Extraction and general properties of the retained
#'   optimizer-path information are tested (structure, lengths, finite
#'   values), not specific values.

skip_if_no_torch = function() {
    skip_if_not_installed("torch")
    skip_if_not(torch::torch_is_installed(), "Torch backend not available")
}

train_tiny = function(epochs = 20, ...) {
    set.seed(42)
    torch::torch_manual_seed(42)
    train_nn(
        x = as.matrix(iris[, 2:4]),
        y = iris$Sepal.Length,
        hidden_neurons = 8,
        epochs = epochs,
        learn_rate = 0.05,
        device = "cpu",
        ...
    )
}

test_that("save_kindling/load_kindling round-trips a train_nn fit", {
    skip_if_no_torch()
    fit = train_tiny()
    x_new = as.matrix(iris[, 2:4])
    pred_before = predict(fit, newdata = x_new)

    path = tempfile(fileext = ".rds")
    withr::defer(unlink(path))
    expect_invisible(save_kindling(fit, path))

    fit2 = load_kindling(path)
    expect_s3_class(fit2, "nn_fit")
    expect_identical(fit2$device, "cpu")
    expect_equal(predict(fit2, newdata = x_new), pred_before, tolerance = 1e-6)
    expect_equal(fit2$loss_history, fit$loss_history)
    expect_equal(fit2$feature_names, fit$feature_names)
})

test_that("save_kindling round-trips ffnn and rnn fits", {
    skip_if_no_torch()
    d = data.frame(a = rnorm(30), b = rnorm(30), y = rnorm(30))
    for (fn in list(ffnn, rnn)) {
        set.seed(1)
        torch::torch_manual_seed(1)
        fit = fn(y ~ ., data = d, hidden_neurons = 4, epochs = 3, device = "cpu")
        path = tempfile(fileext = ".rds")
        save_kindling(fit, path)
        fit2 = load_kindling(path)
        expect_equal(
            predict(fit2, newdata = d[1:5, ]),
            predict(fit, newdata = d[1:5, ]),
            tolerance = 1e-6
        )
        unlink(path)
    }
})

test_that("save_kindling and load_kindling error informatively on bad input", {
    skip_if_no_torch()
    expect_error(save_kindling(lm(mpg ~ wt, mtcars), tempfile()), class = "kindling_input_error")
    expect_error(save_kindling(train_tiny(epochs = 2), path = c("a", "b")), class = "kindling_input_error")
    expect_error(load_kindling(tempfile()), class = "kindling_input_error")
    plain = tempfile(fileext = ".rds")
    withr::defer(unlink(plain))
    saveRDS(list(1, 2), plain)
    expect_error(load_kindling(plain), class = "kindling_input_error")
})

test_that("initial_model warm-starts training and leaves the source untouched", {
    skip_if_no_torch()
    fit1 = train_tiny(epochs = 60)
    params_before = lapply(fit1$model$parameters, function(p) as.numeric(p$cpu()))

    set.seed(7)
    torch::torch_manual_seed(7)
    warm = train_nn(
        x = as.matrix(iris[, 2:4]), y = iris$Sepal.Length,
        initial_model = fit1, epochs = 5, learn_rate = 0.05, device = "cpu"
    )
    set.seed(7)
    torch::torch_manual_seed(7)
    cold = train_nn(
        x = as.matrix(iris[, 2:4]), y = iris$Sepal.Length,
        hidden_neurons = 8, epochs = 5, learn_rate = 0.05, device = "cpu"
    )

    # warm start begins near the previous optimum: first-epoch loss is
    # well below the cold start's
    expect_lt(warm$loss_history[1], cold$loss_history[1])
    # architecture metadata inherited
    expect_identical(warm$hidden_neurons, fit1$hidden_neurons)
    # the supplied model was deep-copied, not mutated
    params_after = lapply(fit1$model$parameters, function(p) as.numeric(p$cpu()))
    expect_identical(params_before, params_after)
})

test_that("a reloaded model can be re-submitted for continued training", {
    skip_if_no_torch()
    fit1 = train_tiny(epochs = 40)
    path = tempfile(fileext = ".rds")
    withr::defer(unlink(path))
    save_kindling(fit1, path)
    fit2 = load_kindling(path)

    continued = train_nn(
        x = as.matrix(iris[, 2:4]), y = iris$Sepal.Length,
        initial_model = fit2, epochs = 3, learn_rate = 0.05, device = "cpu"
    )
    expect_s3_class(continued, "nn_fit")
    expect_lte(continued$loss_history[1], fit1$loss_history[1])
})

test_that("initial_model rejects non-models and dimension mismatches", {
    skip_if_no_torch()
    expect_error(
        train_nn(as.matrix(iris[, 2:4]), iris$Sepal.Length,
                 initial_model = "not a model", epochs = 2),
        class = "kindling_input_error"
    )
    fit = train_tiny(epochs = 2)
    expect_error(
        train_nn(as.matrix(iris[, 1:4]), iris$Sepal.Length,
                 initial_model = fit, epochs = 2),
        class = "kindling_input_error"
    )
})

test_that("track_optim_path retains a well-formed optimizer path", {
    skip_if_no_torch()
    fit = train_tiny(epochs = 10, track_optim_path = TRUE)
    op = fit$optim_path
    expect_s3_class(op, "data.frame")
    expect_equal(nrow(op), fit$n_epochs)
    expect_named(op, c("epoch", "loss", "grad_norm", "param_hash"))
    expect_true(all(is.finite(op$loss)))
    expect_true(all(is.finite(op$grad_norm)))
    expect_true(all(op$grad_norm >= 0))
    # parameters actually move: hashes are not all identical
    expect_gt(length(unique(op$param_hash)), 1L)
    # off by default
    expect_null(train_tiny(epochs = 2)$optim_path)
    # validated flag
    expect_error(train_tiny(epochs = 2, track_optim_path = "yes"),
                 class = "kindling_input_error")
})

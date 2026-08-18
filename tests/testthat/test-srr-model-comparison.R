#' @srrstats {ML7.3} kindling's model-object functionality is explicitly
#'   compared in tests against an equivalent neural-network model class
#'   from another package: `nnet::nnet` (a recommended package, so the
#'   comparison always runs). The design-level comparison with brulee,
#'   cito, and luz lives in `vignette("similar-packages")`.
#' @srrstats {ML7.3a} Restrictions of kindling fits relative to nnet are
#'   identified explicitly: no `coef()`/`summary()` interface (weights are
#'   exposed through `cached_weights`/`$model$parameters` instead).
#' @srrstats {ML7.3b} Unique abilities relative to nnet are identified
#'   explicitly: retained per-epoch loss history, `autoplot()`/`plot()`
#'   methods, optional optimizer-path retention, and torch-safe
#'   save/reload.

skip_if_no_torch = function() {
    skip_if_not_installed("torch")
    skip_if_not(torch::torch_is_installed(), "Torch backend not available")
}

test_that("kindling fits compare with nnet fits: shared and unique functionality", {
    skip_if_no_torch()
    skip_if_not_installed("nnet")
    skip_if_not_installed("ggplot2")

    dat = data.frame(
        x1 = as.numeric(scale(mtcars$wt)),
        x2 = as.numeric(scale(mtcars$hp)),
        y = as.numeric(scale(mtcars$mpg))
    )

    set.seed(42)
    torch::torch_manual_seed(42)
    fit_k = train_nn(
        y ~ x1 + x2, data = dat,
        hidden_neurons = 4, activations = "sigmoid",
        epochs = 50, learn_rate = 0.05, device = "cpu",
        cache_weights = TRUE
    )
    set.seed(42)
    fit_n = nnet::nnet(y ~ x1 + x2, data = dat, size = 4, linout = TRUE, trace = FALSE)

    # shared functionality: both classes predict on new data
    newd = dat[1:6, ]
    expect_length(as.numeric(predict(fit_k, newdata = newd)), 6L)
    expect_length(as.numeric(predict(fit_n, newdata = newd)), 6L)

    # ML7.3a -- restrictions of kindling fits vs nnet:
    # nnet exposes a flat coefficient vector and a summary() method;
    # kindling implements neither ...
    expect_true(is.numeric(fit_n$wts) && length(fit_n$wts) > 0L)
    expect_null(stats::coef(fit_k))
    # ... weights are exposed differently, via cached_weights and the
    # torch module's parameters
    expect_true(is.list(fit_k$cached_weights))
    expect_true(length(fit_k$model$parameters) > 0L)

    # ML7.3b -- unique abilities of kindling fits vs nnet:
    # retained per-epoch loss history (nnet keeps only the final value)
    expect_length(fit_k$loss_history, fit_k$n_epochs)
    expect_null(fit_n$loss_history)
    expect_length(fit_n$value, 1L)
    # plot/autoplot methods on the fit
    expect_s3_class(ggplot2::autoplot(fit_k), "gg")
    expect_error(ggplot2::autoplot(fit_n))
    # torch-safe save/reload with identical predictions
    path = tempfile(fileext = ".rds")
    withr::defer(unlink(path))
    save_kindling(fit_k, path)
    expect_equal(
        as.numeric(predict(load_kindling(path), newdata = newd)),
        as.numeric(predict(fit_k, newdata = newd)),
        tolerance = 1e-6
    )
})

#' @srrstats {G5.4} Correctness tests: a zero-hidden-layer network fitted
#'   on fixed simulated data is compared against a reference
#'   implementation.
#' @srrstats {G5.4b} The reference is an existing implementation
#'   (`stats::lm()`): the special-case equivalence documented in
#'   `vignette("special-cases")` is verified numerically here.
#' @srrstats {G5.5} All correctness tests run under fixed random seeds
#'   (both R's and torch's).
#' @srrstats {G5.6} Parameter recovery: the network's weights are compared
#'   against the known coefficients of the generating linear model.
#' @srrstats {G5.6a} Recovery is asserted within a numeric tolerance, not
#'   exactly.
#' @srrstats {G5.3} Returned fitted values and predictions are tested to
#'   contain no missing or undefined values.
#' @srrstats {G5.7} Algorithm performance: convergence behaviour responds
#'   as expected to the early-stopping improvement threshold, and the
#'   training loss decreases over epochs.
#' @srrstats {G5.9} Noise-susceptibility tests below.
#' @srrstats {G5.9a} Adding trivial noise (scale of
#'   `.Machine$double.eps`) to the data does not meaningfully change
#'   results.
#' @srrstats {G5.9b} Different random seeds do not meaningfully change
#'   results on well-behaved data.
#' @srrstats {ML7.4} Divergence with an inappropriately large training
#'   rate is demonstrated (complementing the learning-rate guidance in
#'   `?train_nn`).
#' @srrstats {ML7.6} The effect of lesser versus greater numbers of epochs
#'   is demonstrated via the recorded loss history.
#' @srrstats {ML7.9} Combinations of categorically different model
#'   architectures and optimization algorithms are tested.
#' @srrstats {ML7.9a} The combinations are generated with `expand.grid()`.
#' @srrstats {ML7.10} Extraction and general properties of the retained
#'   optimizer-path information (`loss_history`) are tested.

skip_if_no_torch = function() {
    skip_if_not_installed("torch")
    skip_if_not(torch::torch_is_installed(), "Torch backend not available")
}

make_linear_data = function(n, sd = 0.05, seed = 42) {
    set.seed(seed)
    x1 = runif(n)
    x2 = runif(n)
    data.frame(x1, x2, y = 3 + 2 * x1 - 1.5 * x2 + rnorm(n, sd = sd))
}

fit_linear_nn = function(dat, epochs = 400, seed = 42, learn_rate = 0.05) {
    set.seed(seed)
    torch::torch_manual_seed(seed)
    train_nn(
        y ~ x1 + x2, data = dat,
        epochs = epochs, batch_size = 32,
        learn_rate = learn_rate, loss = "mse", device = "cpu"
    )
}

test_that("zero-hidden-layer network recovers linear-model coefficients", {
    skip_if_no_torch()
    dat = make_linear_data(200)
    fit_nn = fit_linear_nn(dat)
    fit_ref = lm(y ~ x1 + x2, data = dat)

    # parameter recovery against the known generating coefficients
    W = NULL
    b = NULL
    for (p in fit_nn$model$parameters) {
        v = as.numeric(p$cpu())
        if (length(v) == 2L) W = v else if (length(v) == 1L) b = v
    }
    expect_false(is.null(W))
    expect_false(is.null(b))
    expect_lt(max(abs(W - c(2, -1.5))), 0.2)
    expect_lt(abs(b - 3), 0.2)

    # correctness against the reference implementation
    pred_nn = predict(fit_nn, newdata = dat)
    pred_ref = unname(predict(fit_ref, newdata = dat))
    expect_lt(mean(abs(pred_nn - pred_ref)), 0.1)

    # G5.3: no missing or undefined values in returned results
    expect_false(anyNA(fit_nn$fitted))
    expect_true(all(is.finite(pred_nn)))
    expect_true(all(is.finite(fit_nn$loss_history)))
})

test_that("training loss decreases over epochs (G5.7, ML7.6)", {
    skip_if_no_torch()
    dat = make_linear_data(120)
    fit = fit_linear_nn(dat, epochs = 100)
    lh = fit$loss_history
    expect_length(lh, fit$n_epochs)
    # more epochs give lower loss than fewer epochs
    expect_lt(lh[length(lh)], lh[5])
    expect_lt(lh[length(lh)], lh[1])
})

test_that("a larger early-stopping threshold stops training earlier (G5.7)", {
    skip_if_no_torch()
    dat = make_linear_data(120)
    fit_loose = local({
        set.seed(7)
        torch::torch_manual_seed(7)
        train_nn(
            y ~ x1 + x2, data = dat, epochs = 200, learn_rate = 0.05,
            device = "cpu",
            early_stopping = early_stop(patience = 3, min_delta = 0.5, monitor = "train_loss")
        )
    })
    fit_tight = local({
        set.seed(7)
        torch::torch_manual_seed(7)
        train_nn(
            y ~ x1 + x2, data = dat, epochs = 200, learn_rate = 0.05,
            device = "cpu",
            early_stopping = early_stop(patience = 3, min_delta = 1e-8, monitor = "train_loss")
        )
    })
    expect_lt(fit_loose$n_epochs, fit_tight$n_epochs)
})

test_that("trivial noise does not meaningfully change results (G5.9a)", {
    skip_if_no_torch()
    dat = make_linear_data(120)
    dat_eps = dat
    set.seed(99)
    dat_eps$x1 = dat_eps$x1 + rnorm(nrow(dat_eps)) * .Machine$double.eps
    dat_eps$x2 = dat_eps$x2 + rnorm(nrow(dat_eps)) * .Machine$double.eps

    fit_a = fit_linear_nn(dat, epochs = 150, seed = 1)
    fit_b = fit_linear_nn(dat_eps, epochs = 150, seed = 1)
    expect_lt(mean(abs(predict(fit_a, dat) - predict(fit_b, dat_eps))), 0.05)
})

test_that("different seeds do not meaningfully change results (G5.9b)", {
    skip_if_no_torch()
    dat = make_linear_data(120)
    fit_a = fit_linear_nn(dat, epochs = 200, seed = 1)
    fit_b = fit_linear_nn(dat, epochs = 200, seed = 2)
    expect_lt(mean(abs(predict(fit_a, dat) - predict(fit_b, dat))), 0.1)
})

test_that("an inappropriately large training rate diverges (ML7.4)", {
    skip_if_no_torch()
    dat = make_linear_data(120)
    set.seed(3)
    torch::torch_manual_seed(3)
    fit = train_nn(
        y ~ x1 + x2, data = dat,
        epochs = 30, learn_rate = 100, optimizer = "sgd", device = "cpu"
    )
    lh = fit$loss_history
    last = lh[length(lh)]
    expect_true(!is.finite(last) || last > lh[1])
})

test_that("architecture x optimizer combinations all train (ML7.9, ML7.9a, ML7.10)", {
    skip_if_no_torch()
    dat = make_linear_data(60)
    combos = expand.grid(
        hidden = list(16L, c(16L, 8L)),
        optimizer = c("adam", "sgd"),
        stringsAsFactors = FALSE
    )
    for (i in seq_len(nrow(combos))) {
        set.seed(5)
        torch::torch_manual_seed(5)
        fit = train_nn(
            y ~ x1 + x2, data = dat,
            hidden_neurons = combos$hidden[[i]],
            activations = "relu",
            optimizer = combos$optimizer[[i]],
            epochs = 3, device = "cpu"
        )
        expect_s3_class(fit, "nn_fit")
        # ML7.10: general properties of the retained optimizer path
        expect_type(fit$loss_history, "double")
        expect_length(fit$loss_history, fit$n_epochs)
        expect_true(all(is.finite(fit$loss_history)))
    }
})

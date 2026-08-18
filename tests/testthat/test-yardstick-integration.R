#' @srrstats {ML7.11} The performance metrics available for kindling fits
#'   (via the documented yardstick integration) are tested on model
#'   predictions here.
#' @srrstats {ML7.11a} Metrics are compared across differently trained
#'   models (see the multi-metric comparison test below).

skip_if_no_torch = function() {
    skip_if_not_installed("torch")
    skip_if_not(torch::torch_is_installed(), "Torch backend not available")
}

test_that("classification metrics work with mlp predictions", {
    skip_if_not_installed("parsnip")
    skip_if_not_installed("yardstick")
    skip_if_no_torch()

    spec = mlp_kindling(
        mode = "classification",
        hidden_neurons = c(20),
        epochs = 10,
        verbose = FALSE
    )

    fitted = parsnip::fit(
        spec,
        Species ~ .,
        data = iris
    )

    results = parsnip::augment(fitted, new_data = iris)

    metrics = yardstick::metrics(
        results,
        truth = Species,
        estimate = .pred_class
    )

    expect_s3_class(metrics, "tbl_df")
    expect_true("accuracy" %in% metrics$.metric)
    expect_true("kap" %in% metrics$.metric)
})

test_that("regression metrics work with mlp predictions", {
    skip_if_not_installed("parsnip")
    skip_if_not_installed("yardstick")
    skip_if_no_torch()

    spec = mlp_kindling(
        mode = "regression",
        hidden_neurons = c(20),
        epochs = 10,
        verbose = FALSE
    )

    fitted = parsnip::fit(
        spec,
        Sepal.Length ~ .,
        data = iris
    )

    results = parsnip::augment(fitted, new_data = iris)

    metrics = yardstick::metrics(
        results,
        truth = Sepal.Length,
        estimate = .pred
    )

    expect_s3_class(metrics, "tbl_df")
    expect_true("rmse" %in% metrics$.metric)
    expect_true("rsq" %in% metrics$.metric)
    expect_true("mae" %in% metrics$.metric)
})

test_that("multiple metrics compare consistently across differently trained models", {
    skip_if_not_installed("parsnip")
    skip_if_not_installed("yardstick")
    skip_if_no_torch()

    spec_short = mlp_kindling(
        mode = "regression", hidden_neurons = 8,
        epochs = 2, learn_rate = 0.05
    )
    spec_long = mlp_kindling(
        mode = "regression", hidden_neurons = 8,
        epochs = 60, learn_rate = 0.05
    )

    set.seed(11)
    torch::torch_manual_seed(11)
    fit_short = parsnip::fit(spec_short, Sepal.Length ~ ., data = iris[, 1:4])
    set.seed(11)
    torch::torch_manual_seed(11)
    fit_long = parsnip::fit(spec_long, Sepal.Length ~ ., data = iris[, 1:4])

    ms = yardstick::metric_set(yardstick::rmse, yardstick::mae, yardstick::rsq)
    res_short = ms(
        parsnip::augment(fit_short, new_data = iris[, 1:4]),
        truth = Sepal.Length, estimate = .pred
    )
    res_long = ms(
        parsnip::augment(fit_long, new_data = iris[, 1:4]),
        truth = Sepal.Length, estimate = .pred
    )

    expect_setequal(res_short$.metric, c("rmse", "mae", "rsq"))
    expect_setequal(res_long$.metric, c("rmse", "mae", "rsq"))
    rmse_short = res_short$.estimate[res_short$.metric == "rmse"]
    rmse_long = res_long$.estimate[res_long$.metric == "rmse"]
    expect_lt(rmse_long, rmse_short)
})

#' @srrstats {G5.10} Extended tests run under the common testthat framework
#'   but are switched on by the `KINDLING_EXTENDED_TESTS="true"` environment
#'   variable (see `tests/README.md`).
#' @srrstats {G5.6b} Parameter recovery is repeated under multiple random
#'   seeds here (the algorithm contains stochastic components: weight
#'   initialization and batch shuffling).

skip_if_no_torch = function() {
    skip_if_not_installed("torch")
    skip_if_not(torch::torch_is_installed(), "Torch backend not available")
}

skip_if_not_extended = function() {
    skip_if_not(
        identical(Sys.getenv("KINDLING_EXTENDED_TESTS"), "true"),
        "Extended tests disabled (set KINDLING_EXTENDED_TESTS=true)"
    )
}

test_that("extended: parameter recovery holds across multiple seeds", {
    skip_if_no_torch()
    skip_if_not_extended()

    for (seed in c(1L, 42L, 2026L)) {
        set.seed(seed)
        x1 = runif(200)
        x2 = runif(200)
        dat = data.frame(x1, x2, y = 3 + 2 * x1 - 1.5 * x2 + rnorm(200, sd = 0.05))

        set.seed(seed)
        torch::torch_manual_seed(seed)
        fit = train_nn(
            y ~ x1 + x2, data = dat,
            epochs = 400, batch_size = 32, learn_rate = 0.05,
            loss = "mse", device = "cpu"
        )

        W = NULL
        b = NULL
        for (p in fit$model$parameters) {
            v = as.numeric(p$cpu())
            if (length(v) == 2L) W = v else if (length(v) == 1L) b = v
        }
        expect_lt(max(abs(W - c(2, -1.5))), 0.2)
        expect_lt(abs(b - 3), 0.2)
    }
})

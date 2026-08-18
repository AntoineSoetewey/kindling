#' @srrstats {G5.2b} Together with the error-condition tests spread through
#'   the suite, the tests in this file demonstrate the conditions that
#'   trigger every message (error, warning, or informational) emitted by
#'   kindling's R code. The gap list was derived mechanically: run
#'   `covr::package_coverage(type = "tests")` and enumerate every
#'   condition-raising line with zero coverage; each such line received a
#'   test here. Internal validators are called directly (`kindling:::`)
#'   where the public API cannot reach a branch, and
#'   `testthat::local_mocked_bindings()` simulates absent dependencies for
#'   the "package X is required" guards. Three defensive sites are
#'   exercised only by inspection, documented at the bottom of this file.

skip_if_no_torch = function() {
    skip_if_not_installed("torch")
    skip_if_not(torch::torch_is_installed(), "Torch backend not available")
}

x_small = matrix(rnorm(40), ncol = 2, dimnames = list(NULL, c("a", "b")))
y_small = rnorm(20)

make_ds = function(n = 6, y_maker = function(data, i) torch::torch_tensor(1L)) {
    torch::dataset(
        name = "msg_test_ds",
        initialize = function() {
            self$x = torch::torch_randn(n, 3)
            self$n = n
        },
        .getitem = function(i) list(self$x[i, ], y_maker(self, i)),
        .length = function() self$n
    )()
}

# ---- dependency-missing guards (mocked) --------------------------------

test_that("torch-missing guards error informatively in every entry point", {
    skip_if_no_torch()
    local_mocked_bindings(requireNamespace = function(...) FALSE, .package = "kindling")

    msg = "torch.*required but not installed"
    expect_error(train_nn(x_small, y_small, epochs = 1), msg)
    expect_error(kindling:::ffnn_impl(x_small, y_small, hidden_neurons = 2), msg)
    expect_error(kindling:::rnn_impl(x_small, y_small, hidden_neurons = 2), msg)
    expect_error(predict(structure(list(), class = "nn_fit"), newdata = x_small), msg)
    expect_error(predict(structure(list(), class = "ffnn_fit"), newdata = x_small), msg)
    expect_error(predict(structure(list(), class = "rnn_fit"), newdata = x_small), msg)
    expect_error(garson(structure(list(), class = "ffnn_fit")), msg)
    expect_error(olden(structure(list(), class = "ffnn_fit")), msg)
})

test_that("torch-missing guard covers the dataset method too", {
    skip_if_no_torch()
    ds = make_ds()
    local_mocked_bindings(requireNamespace = function(...) FALSE, .package = "kindling")
    expect_error(train_nn(ds, epochs = 1), "torch.*required but not installed")
})

test_that("parsnip-missing guards error informatively", {
    skip_if_no_torch()
    local_mocked_bindings(requireNamespace = function(...) FALSE, .package = "kindling")
    msg = "parsnip.*required but not installed"
    expect_error(train_nnsnip(), msg)
    expect_error(mlp_kindling(), msg)
    expect_error(rnn_kindling(), msg)
})

test_that("grid-backend-missing guards error informatively", {
    skip_if_no_torch()
    local_mocked_bindings(
        requireNamespace = function(pkg, ...) FALSE,
        .package = "kindling"
    )
    expect_error(kindling:::generate_lhs_grid(), "lhs.*required")
    expect_error(kindling:::generate_sfd_grid(), "sfd.*required")
})

test_that("DiceDesign-missing guard errors informatively", {
    skip_if_not_installed("sfd")
    skip_if_not_installed("dials")
    skip_if_not_installed("dplyr")
    skip_if(sfd::sfd_available(2, 997, "audze_eglais"),
            "premade design unexpectedly available")
    local_mocked_bindings(
        requireNamespace = function(pkg, ...) !identical(pkg, "DiceDesign"),
        .package = "kindling"
    )
    expect_error(
        kindling:::generate_sfd_grid(
            neuron_param = NULL, activation_param = NULL, n_hlayer = 1,
            scalar_params = list(p1 = dials::penalty(), p2 = dials::learn_rate()),
            size = 997, sfd_type = "audze_eglais",
            variogram_range = 0.5, iter = 10, original = TRUE
        ),
        "DiceDesign"
    )
})

test_that("is_installed torch guard in validate_optimizer errors informatively", {
    local_mocked_bindings(is_installed = function(...) FALSE, .package = "kindling")
    expect_error(kindling:::validate_optimizer("adam"), class = "torch_missing_error")
})

test_that("new_act_fn warns and skips the probe when torch is missing", {
    local_mocked_bindings(requireNamespace = function(...) FALSE, .package = "kindling")
    expect_warning(new_act_fn(function(x) x), "skipping dry-run probe")
})

# ---- constructor / validator messages ----------------------------------

test_that("early_stop() validates its inputs", {
    expect_error(early_stop(patience = 0), "positive integer")
    expect_error(early_stop(min_delta = -1), "non-negative")
})

test_that("conflicting architecture and arch arguments error", {
    skip_if_no_torch()
    expect_error(
        train_nn(x_small, y_small, epochs = 1,
                 arch = nn_arch(nn_name = "a"), architecture = nn_arch(nn_name = "b")),
        "both supplied with different values"
    )
})

test_that("new_act_fn probe failures error informatively", {
    skip_if_no_torch()
    expect_error(
        new_act_fn(function(x) stop("boom")),
        class = "custom_activation_probe_error"
    )
})

test_that("custom loss validation covers probe error, shape warning, and call-time guard", {
    skip_if_no_torch()
    expect_error(
        kindling:::.validate_loss_fn(function(input, target) stop("boom")),
        class = "loss_fn_probe_error"
    )
    expect_warning(
        kindling:::.validate_loss_fn(function(input, target) torch::torch_abs(input - target)),
        class = "loss_fn_shape_warning"
    )
    calls = 0
    sneaky = function(input, target) {
        calls <<- calls + 1
        if (calls > 1) 42 else torch::nnf_mse_loss(input, target)
    }
    wrapper = kindling:::.validate_loss_fn(sneaky)
    expect_error(
        wrapper(torch::torch_randn(c(2L, 1L)), torch::torch_randn(c(2L, 1L))),
        class = "loss_fn_output_error"
    )
})

test_that("device fallback warnings and rejections are exercised", {
    skip_if_no_torch()
    if (!torch::cuda_is_available()) {
        expect_warning(out <- kindling:::validate_device("cuda"), "CUDA not available")
        expect_identical(out, "cpu")
    } else {
        expect_identical(kindling:::validate_device("cuda"), "cuda")
    }
    if (!torch::backends_mps_is_available()) {
        expect_warning(out <- kindling:::validate_device("mps"), "MPS not available")
        expect_identical(out, "cpu")
    } else {
        expect_identical(kindling:::validate_device("mps"), "mps")
    }
})

test_that("table_summary rejects non-two-column input", {
    expect_error(table_summary(data.frame(a = 1)), "exactly 2 columns")
})

test_that("generator validation messages are exercised", {
    skip_if_no_torch()
    expect_error(
        nn_module_generator(hd_neurons = 4, no_x = 2, no_y = 1, out_nn_layer = 42),
        "must be a string, symbol, or function"
    )
    expect_error(
        nn_module_generator(hd_neurons = 4, no_x = 2, no_y = 1, layer_arg_fn = 42),
        "Expected a formula or function"
    )
    expect_error(
        nn_module_generator(hd_neurons = 4, no_x = 2, no_y = 1, after_output_transform = 42),
        "Expected a formula or function"
    )
    expect_error(
        structure(list(), class = c("layer_pr", "list"))$bogus,
        "Unknown layer pronoun field"
    )
    expect_error(
        ffnn_generator(hd_neurons = NULL, no_x = integer(0), no_y = integer(0)),
        class = "nn_module_error"
    )
    expect_error(
        rnn_generator(rnn_type = "bogus", hd_neurons = 4, no_x = 2, no_y = 1),
        class = "rnn_type_error"
    )
    expect_error(
        rnn_generator(rnn_type = "lstm", hd_neurons = NULL, no_x = 2, no_y = 1),
        class = "rnn_module_error"
    )
})

test_that("grid generation with no parameters errors", {
    expect_error(
        kindling:::generate_grid(
            neuron_param = NULL, activation_param = NULL, n_hlayer = NULL,
            scalar_params = list(), type = "regular", size = 5, levels = 3,
            original = TRUE, variogram_range = 0.5, iter = 10
        ),
        "No parameters provided"
    )
})

test_that("translate methods require an engine", {
    expect_error(kindling:::translate.mlp_kindling(list(engine = NULL)), "set_engine")
    expect_error(kindling:::translate.rnn_kindling(list(engine = NULL)), "set_engine")
    expect_error(kindling:::translate.train_nnsnip(list(engine = NULL)), "set_engine")
})

# ---- ffnn()/rnn() interface messages -----------------------------------

test_that("ffnn and rnn interface validation messages are exercised", {
    skip_if_no_torch()
    d = data.frame(a = rnorm(20), b = rnorm(20), y = rnorm(20))
    for (fn in list(ffnn, rnn)) {
        expect_error(fn(x = d[, 1:2], hidden_neurons = 2, epochs = 1),
                     "Both.*x.*and.*y.*must be provided")
        expect_error(fn(y ~ ., hidden_neurons = 2, epochs = 1),
                     "data.*must be provided")
        expect_error(fn(hidden_neurons = 2, epochs = 1),
                     "Must provide either")
        expect_warning(
            fn(y ~ ., data = d, x = d[, 1:2], y = d$y,
               hidden_neurons = 2, epochs = 1, device = "cpu"),
            "Using x/y interface"
        )
    }
})

# ---- predict()-time messages -------------------------------------------

test_that("probability-prediction misuse errors are exercised", {
    skip_if_no_torch()
    d_cls = data.frame(a = rnorm(20), b = rnorm(20),
                       y = factor(rep(c("u", "v"), 10)))
    fit_gen_cls = train_nn(d_cls[, 1:2], d_cls$y, epochs = 1, device = "cpu")
    fit_gen_reg = train_nn(x_small, y_small, epochs = 1, device = "cpu")
    fit_ffnn_cls = ffnn(y ~ ., data = d_cls, hidden_neurons = 2, epochs = 1, device = "cpu")
    fit_rnn_cls = rnn(y ~ ., data = d_cls, hidden_neurons = 2, epochs = 1, device = "cpu")

    expect_error(predict(fit_gen_cls, type = "prob"), "without.*newdata")
    expect_error(predict(fit_gen_reg, type = "prob"), "only available for classification")
    expect_error(predict(fit_ffnn_cls, type = "prob"), "without.*newdata")
    expect_error(predict(fit_rnn_cls, type = "prob"), "without.*newdata")
    # non-numeric newdata is rejected by the shared guard
    expect_error(predict(fit_gen_reg, newdata = matrix(letters[1:4], 2)),
                 class = "kindling_input_error")
})

# ---- dataset-method messages -------------------------------------------

test_that("dataset-method validation messages are exercised", {
    skip_if_no_torch()

    ds_empty = make_ds(n = 0)
    expect_error(train_nn(ds_empty, epochs = 1), "dataset is empty")

    ds_bad_label = make_ds(y_maker = function(data, i) 5)
    expect_error(train_nn(ds_bad_label, epochs = 1), "two torch tensors")

    ds_vec_label = make_ds(y_maker = function(data, i) torch::torch_randn(2))
    expect_warning(
        train_nn(ds_vec_label, n_classes = 3, hidden_neurons = 2,
                 epochs = 1, batch_size = 2, device = "cpu"),
        "n_classes.*ignored"
    )

    expect_error(kindling:::.resolve_flatten_input("yes"), "single TRUE or FALSE")

    failing_ds = torch::dataset(
        name = "failing_ds",
        initialize = function() NULL,
        .getitem = function(i) stop("boom"),
        .length = function() 5
    )()
    expect_error(kindling:::.dataset_get_item(failing_ds, 1), "Failed to read item")
    expect_error(kindling:::.dataset_get_item(list(1, 2), 1), "at least two elements")

    expect_error(
        kindling:::train_nn_impl_dataset(
            dataset = list(), no_x = 2L, no_y = 1L, is_classification = FALSE,
            hidden_neurons = 2
        ),
        "empty"
    )

    ds_ok = make_ds(y_maker = function(data, i) torch::torch_tensor(1))
    fit_ds = train_nn(ds_ok, hidden_neurons = 2, epochs = 1, batch_size = 2, device = "cpu")
    expect_error(predict(fit_ds, newdata = identity), "Unsupported.*newdata")
})

# ---- diagnostics-plot messages -----------------------------------------

test_that("diagnostic-plot messages are exercised", {
    skip_if_no_torch()
    expect_error(
        autoplot_diagnostics(structure(list(fitted = NULL), class = "nn_fit"),
                             actual = 1:3),
        "require fitted values"
    )
    y_mat = cbind(y1 = rnorm(20), y2 = rnorm(20))
    fit_multi = train_nn(x_small, y_mat, epochs = 1, device = "cpu")
    expect_message(
        autoplot_diagnostics(fit_multi, actual = y_mat),
        "one plot per output column"
    )
})

# ---- documented exemptions ---------------------------------------------
# Three condition sites are not triggerable through any supported input
# and are verified by inspection instead:
# - R/generalized-nn-fit.R + R/generalized-nn-fitds.R "Weight caching
#   failed" warnings: defensive tryCatch handlers around plain matrix
#   conversions of trained parameters, which cannot fail for any module
#   the package can construct.
# - R/generalized-nn-fitds.R "Dataset labels must be torch tensors."
#   (train_nn.dataset body): unreachable defensive branch, because the
#   method already rejects non-tensor labels at its entry ("two torch
#   tensors" guard, tested above).

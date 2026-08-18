#' Generalized Neural Network Trainer
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' `train_nn()` is a generic function for training neural networks with a
#' user-defined architecture via [nn_arch()]. Dispatch is based on the class
#' of `x`.
#'
#' Recommended workflow:
#' 1. Define architecture with [nn_arch()] (optional).
#' 2. Train with `train_nn()`.
#' 3. Predict with [predict.nn_fit()].
#'
#' All methods delegate to a shared implementation core after preprocessing.
#' When `architecture = NULL`, the model falls back to a plain feed-forward neural network
#' (`nn_linear`) architecture.
#'
#' @param x Dispatch is based on its current class:
#'   - `matrix`: used directly, no preprocessing applied.
#'   - `data.frame`: preprocessed via `hardhat::mold()`. `y` may be a vector /
#'     factor / matrix of outcomes, or a formula describing the outcome–predictor
#'     relationship within `x`.
#'   - `formula`: combined with `data` and preprocessed via `hardhat::mold()`.
#'   - `dataset`: a `torch` dataset object; batched via `torch::dataloader()`.
#'     This is the recommended interface for sequence/time-series and image data.
#' @param y Outcome data. Interpretation depends on the method:
#'   - For the `matrix` and `data.frame` methods: a numeric vector, factor, or
#'     matrix of outcomes.
#'   - For the `data.frame` method only: alternatively a formula of the form
#'     `outcome ~ predictors`, evaluated against `x`.
#'   - Ignored when `x` is a formula (outcome is taken from the formula) or a
#'     `dataset` (labels come from the dataset itself).
#' @param data A data frame. Required when `x` is a formula.
#' @param hidden_neurons Integer vector specifying the number of neurons in each
#'   hidden layer, e.g. `c(128, 64)` for two hidden layers. When `NULL` or missing,
#'   no hidden layers are used and the model reduces to a single linear mapping
#'   from inputs to outputs.
#' @param activations Activation function specification(s) for the hidden layers.
#'   See [act_funs()] for supported values. Recycled if a single value is given.
#' @param output_activation Optional activation function for the output layer.
#'   Defaults to `NULL` (no activation / linear output).
#' @param bias Logical. Whether to include bias terms in each layer. Default `TRUE`.
#' @param architecture An [nn_arch()] object specifying a custom architecture. Default
#'   `NULL`, which falls back to a standard feed-forward network.
#' @param arch Backward-compatible alias for `architecture`. If both are supplied,
#'   they must be identical.
#' @param flatten_input Logical or `NULL` (dataset method only). Controls whether
#'   each batch/sample is flattened to 2D before entering the model. `NULL`
#'   (default) auto-selects: `TRUE` when `architecture = NULL`, otherwise `FALSE`.
#' @param early_stopping An [early_stop()] object specifying early stopping
#'   behaviour, or `NULL` (default) to disable early stopping. When supplied,
#'   training halts if the monitored metric does not improve by at least
#'   `min_delta` for `patience` consecutive epochs.
#'   Example: `early_stopping = early_stop(patience = 10)`.
#' @param epochs Positive integer. Number of full passes over the training data.
#'   Default `100`.
#' @param batch_size Positive integer. Number of samples per mini-batch. Default `32`.
#' @param penalty Non-negative numeric. L1/L2 regularization strength (lambda).
#'   Default `0` (no regularization).
#' @param mixture Numeric in \[0, 1\]. Elastic net mixing parameter: `0` = pure
#'   ridge (L2), `1` = pure lasso (L1). Default `0`.
#' @param learn_rate Positive numeric. Step size for the optimizer. Default `0.001`.
#' @param optimizer Character. Optimizer algorithm. One of `"adam"` (default),
#'   `"sgd"`, or `"rmsprop"`.
#' @param optimizer_args Named list of additional arguments forwarded to the
#'   optimizer constructor (e.g. `list(momentum = 0.9)` for SGD). Default `list()`.
#' @param loss Character or function. Loss function used during training. Built-in
#'   options: `"mse"` (default), `"mae"`, `"cross_entropy"`, or `"bce"`. For
#'   classification tasks with a scalar label, `"cross_entropy"` is set
#'   automatically. Alternatively, supply a custom function or formula with
#'   signature `function(input, target)` returning a scalar `torch_tensor`.
#' @param validation_split Numeric in \[0, 1). Proportion of training data held
#'   out for validation. Default `0` (no validation set).
#' @param device Character. Compute device: `"cpu"`, `"cuda"`, or `"mps"`.
#'   Default `NULL`, which auto-detects the best available device.
#' @param verbose Logical. If `TRUE`, prints loss (and validation loss) at regular
#'   intervals during training. Default `FALSE`.
#' @param cache_weights Logical. If `TRUE`, stores a copy of the trained weight
#'   matrices in the returned object under `$cached_weights`. Default `FALSE`.
#' @param initial_model A previously trained kindling model of class
#'   `nn_fit` -- from an earlier `train_nn()` call or reloaded with
#'   [load_kindling()] -- to warm-start from. Training continues on a deep
#'   copy of its trained module (the supplied object is left untouched).
#'   The architecture arguments (`hidden_neurons`, `activations`,
#'   `output_activation`, `architecture`) are ignored and inherited from
#'   the initial model, whose input/output dimensions must match the
#'   supplied data. Supported by the `matrix`, `data.frame`, and `formula`
#'   methods. Default `NULL` (train from scratch).
#' @param track_optim_path Logical. If `TRUE`, retain per-epoch information
#'   on the path taken by the optimizer in the returned object's
#'   `optim_path` component: the loss value, the global gradient norm, and
#'   a hash of all model parameters at each epoch. Default `FALSE` (only
#'   `loss_history` is retained).
#' @param ... Additional arguments passed to specific methods.
#'
#' @return An object of class `"nn_fit"`, or one of its subclasses:
#'   - `c("nn_fit_tab", "nn_fit")` — returned by the `data.frame` and `formula` methods
#'   - `c("nn_fit_ds", "nn_fit")` — returned by the `dataset` method
#'
#'   All subclasses share a common structure. See **Details** for the list of
#'   components.
#'
#' @details
#' The returned `"nn_fit"` object is a named list with the following components:
#'
#' - `model` — the trained `torch::nn_module` object
#' - `fitted` — fitted values on the training data (or `NULL` for dataset fits)
#' - `loss_history` — numeric vector of per-epoch training loss, trimmed to
#'   actual epochs run (relevant when early stopping is active)
#' - `val_loss_history` — per-epoch validation loss, or `NULL` if
#'   `validation_split = 0`
#' - `optim_path` — when `track_optim_path = TRUE`, a data frame with one
#'   row per epoch (`epoch`, `loss`, `grad_norm`, `param_hash`) recording
#'   the optimizer's path; otherwise `NULL`
#' - `n_epochs` — number of epochs actually trained
#' - `stopped_epoch` — epoch at which early stopping triggered, or `NA` if
#'   training ran to completion
#' - `hidden_neurons`, `activations`, `output_activation` — architecture spec
#' - `penalty`, `mixture` — regularization settings
#' - `feature_names`, `response_name` — variable names (tabular methods only)
#' - `no_x`, `no_y` — number of input features and output nodes
#' - `is_classification` — logical flag
#' - `y_levels`, `n_classes` — class labels and count (classification only)
#' - `device` — device the model is on
#' - `cached_weights` — list of weight matrices, or `NULL`
#' - `arch` — the `nn_arch` object used, or `NULL`
#'
#' @section Supported tasks and input formats:
#' `train_nn()` is task-agnostic by design (no explicit `task` argument).
#' Task behavior is determined by your input interface and architecture:
#' - **Tabular data**: use `matrix`, `data.frame`, or `formula` methods.
#' - **Time series**: use the `dataset` method with per-item tensors shaped as
#'   `[time, features]` (or your preferred convention) and a recurrent
#'   architecture via [nn_arch()].
#' - **Image classification**: use the `dataset` method with per-item tensors
#'   shaped for your first layer (commonly `[channels, height, width]` for
#'   `torch::nn_conv2d`). If your source arrays are channel-last, reorder in the
#'   dataset or via `input_transform`.
#'
#' @examples
#' \donttest{
#' if (torch::torch_is_installed()) {
#'     # Matrix method — no preprocessing
#'     model = train_nn(
#'         x = as.matrix(iris[, 2:4]),
#'         y = iris$Sepal.Length,
#'         hidden_neurons = c(64, 32),
#'         activations = "relu",
#'         epochs = 50
#'     )
#'
#'     # Data frame method — y as a vector
#'     model = train_nn(
#'         x = iris[, 2:4],
#'         y = iris$Sepal.Length,
#'         hidden_neurons = c(64, 32),
#'         activations = "relu",
#'         epochs = 50
#'     )
#'
#'     # Data frame method — y as a formula evaluated against x
#'     model = train_nn(
#'         x = iris,
#'         y = Sepal.Length ~ . - Species,
#'         hidden_neurons = c(64, 32),
#'         activations = "relu",
#'         epochs = 50
#'     )
#'
#'     # Formula method — outcome derived from formula
#'     model = train_nn(
#'         x = Sepal.Length ~ .,
#'         data = iris[, 1:4],
#'         hidden_neurons = c(64, 32),
#'         activations = "relu",
#'         epochs = 50
#'     )
#'
#'     # No hidden layers — linear model
#'     model = train_nn(
#'         x = Sepal.Length ~ .,
#'         data = iris[, 1:4],
#'         epochs = 50
#'     )
#'
#'     # Architecture object (nn_arch -> train_nn)
#'     mlp_arch = nn_arch(nn_name = "mlp_model")
#'     model = train_nn(
#'         x = Sepal.Length ~ .,
#'         data = iris[, 1:4],
#'         hidden_neurons = c(64, 32),
#'         activations = "relu",
#'         architecture = mlp_arch,
#'         epochs = 50
#'     )
#'
#'     # Custom layer architecture
#'     custom_linear = torch::nn_module(
#'         "CustomLinear",
#'         initialize = function(in_features, out_features, bias = TRUE) {
#'             self$layer = torch::nn_linear(in_features, out_features, bias = bias)
#'         },
#'         forward = function(x) self$layer(x)
#'     )
#'     custom_arch = nn_arch(
#'         nn_name = "custom_linear_mlp",
#'         nn_layer = ~ custom_linear
#'     )
#'     model = train_nn(
#'         x = Sepal.Length ~ .,
#'         data = iris[, 1:4],
#'         hidden_neurons = c(16, 8),
#'         activations = "relu",
#'         architecture = custom_arch,
#'         epochs = 50
#'     )
#'
#'     # With early stopping
#'     model = train_nn(
#'         x = Sepal.Length ~ .,
#'         data = iris[, 1:4],
#'         hidden_neurons = c(64, 32),
#'         activations = "relu",
#'         epochs = 200,
#'         validation_split = 0.2,
#'         early_stopping = early_stop(patience = 10)
#'     )
#'
#'     # Track the optimizer's path, then inspect it
#'     model = train_nn(
#'         x = Sepal.Length ~ .,
#'         data = iris[, 1:4],
#'         hidden_neurons = 16,
#'         epochs = 20,
#'         track_optim_path = TRUE
#'     )
#'     head(model$optim_path)
#'
#'     # Warm-start: continue training a previous (or reloaded) model
#'     model2 = train_nn(
#'         x = Sepal.Length ~ .,
#'         data = iris[, 1:4],
#'         initial_model = model,
#'         epochs = 20
#'     )
#' }
#' }
#'
#' @section Training, validation, and test data:
#' `train_nn()` always treats the data it receives as **training** data.
#' A **validation** subset can be carved out of it with `validation_split`
#' (used only to monitor `val_loss_history` and to drive [early_stop()]);
#' **test** data is never seen during training and should be supplied
#' post-hoc to [predict.nn_fit()], or managed by resampling tools such as
#' `rsample::initial_split()` in the tidymodels workflow demonstrated in
#' `vignette("kindling")`. This proportion-based design (rather than
#' labelled train/test inputs) follows tidymodels conventions, where data
#' partitioning is the responsibility of `rsample`/`tune`.
#'
#' Outcomes supplied as `ordered` factors are treated as plain, unordered
#' class labels: the ordering is ignored and the factor levels are used as
#' categories.
#'
#' @section Missing values:
#' kindling models cannot be trained on missing (`NA`) or non-finite
#' (`NaN`, `Inf`) values: torch tensors have no notion of R's `NA`, so all
#' inputs are checked up front and an informative error is raised instead
#' of propagating undefined values. Imputation is deliberately delegated to
#' the pre-processing layer of the modelling workflow, e.g.
#'
#' ``` r
#' recipes::recipe(y ~ ., data = dat) |>
#'     recipes::step_impute_mean(recipes::all_numeric_predictors())
#' ```
#'
#' or drop incomplete rows with `tidyr::drop_na()` before fitting.
#'
#' @section Learning rate, batch size, and epochs:
#' The default `learn_rate = 0.001` is a common starting point for the
#' default `"adam"` optimizer but is not universally valid: too high a rate
#' can make the loss diverge, too low a rate slows convergence. Adaptive
#' optimizers (`"adam"`, `"rmsprop"`) adjust per-parameter step sizes
#' automatically, which is kindling's mechanism for automatic training-rate
#' adaptation; inspect `loss_history` (e.g. via `ggplot2::autoplot()`) to
#' diagnose a poorly chosen rate. Smaller `batch_size` values give noisier
#' but more frequent parameter updates per epoch; larger values give
#' smoother gradients but fewer updates, typically requiring more `epochs`.
#' One *epoch* is one full pass over the training data; each epoch performs
#' `ceiling(n / batch_size)` gradient updates.
#'
#' @srrstats {G1.3} Statistical terminology (epoch, batch, learning rate,
#'   loss, validation split, early stopping) is defined in the parameter
#'   documentation and the dedicated sections above.
#' @srrstats {G2.0a} Length expectations (single values, vectors per hidden
#'   layer) are documented for every parameter above.
#' @srrstats {G2.1a} Data types of all inputs are documented for every
#'   parameter above.
#' @srrstats {G2.3} Univariate character inputs are restricted to
#'   documented sets of values (see `optimizer`, `loss`, `device`).
#' @srrstats {G2.5} The treatment of `ordered` factors (ordering ignored)
#'   is documented in the section on training data above.
#' @srrstats {G2.7} `train_nn()` accepts the standard tabular forms:
#'   `matrix`, `data.frame` (including tibbles, via `hardhat::mold()`),
#'   formula + data, and domain-specific torch `dataset` objects.
#' @srrstats {G2.8} All tabular methods funnel through a single
#'   pre-processing bridge that hands a numeric matrix to the shared
#'   implementation core, so sub-functions receive one defined input class.
#' @srrstats {ML1.0} The documentation above makes the conceptual
#'   distinction between training, validation, and test data explicit.
#' @srrstats {ML1.0a} The same section explains and justifies the
#'   proportion-based `validation_split` design in place of labelled
#'   train/test inputs (tidymodels conventions).
#' @srrstats {ML1.6a} The "Missing values" section explains *why* missing
#'   values are not admitted (torch tensors cannot represent `NA`).
#' @srrstats {ML1.6b} The same section gives explicit example code for
#'   imputing (rather than discarding) missing values via recipes.
#' @srrstats {ML3.4} The importance of, and sensitivity to, training-rate
#'   values is documented in the dedicated section above.
#' @srrstats {ML3.4a} Automatic training-rate adaptation is provided
#'   through the adaptive optimizers (`adam`, `rmsprop`), as documented
#'   above; a separate rate-finder pre-processing stage is deliberately not
#'   implemented.
#' @srrstats {ML3.4b} Restrictions on the validity of the default
#'   `learn_rate` are documented, with guidance to diagnose bad values.
#' @srrstats {ML4.3} Batch-processing terminology (`epochs`, `batch_size`)
#'   is explicitly defined rather than presumed understood.
#' @srrstats {ML4.4} Guidance on trade-offs between batch sizes and numbers
#'   of epochs is given in the dedicated section above.
#' @srrstats {ML3.1} Both untrained models (parameter-specified) and
#'   pre-trained models are supported: `initial_model` accepts a
#'   previously trained (or `load_kindling()`-reloaded) `nn_fit` object
#'   and continues training from it.
#' @srrstats {ML4.2} Extraction of the retained optimizer-path information
#'   is documented in the Details section (`optim_path`, `loss_history`)
#'   and demonstrated in the examples (`head(model$optim_path)`,
#'   `ggplot2::autoplot()`).
#'
#' @seealso [predict.nn_fit()], [nn_arch()], [act_funs()], [early_stop()],
#'   [save_kindling()] / [load_kindling()]
#' @name gen-nn-train
#' @export
train_nn = function(x, ...) {
    UseMethod("train_nn")
}


#' Normalize architecture argument for train_nn()
#' @noRd
.resolve_train_architecture = function(architecture = NULL, arch = NULL) {
    if (!is.null(architecture) && !is.null(arch) && !identical(architecture, arch)) {
        cli::cli_abort(c(
            "{.arg architecture} and {.arg arch} were both supplied with different values.",
            i = "Supply only {.arg architecture}, or provide identical values for both."
        ))
    }

    out = architecture %||% arch

    if (!is.null(out) && !inherits(out, "nn_arch")) {
        cli::cli_abort("{.arg architecture} must be an {.cls nn_arch} object created with {.fn nn_arch}.")
    }

    out
}


#' Normalize predict newdata argument
#' @noRd
.resolve_predict_newdata = function(newdata = NULL, new_data = NULL) {
    if (!is.null(new_data) && is.null(newdata)) {
        cli::cli_warn("{.arg new_data} is a legacy alias. Prefer {.arg newdata}.")
        return(new_data)
    }

    newdata
}

#' @rdname gen-nn-train
#'
#' @section Matrix method:
#' When `x` is supplied as a raw numeric matrix, no preprocessing is applied.
#' Data is passed directly to the shared `train_nn_impl` core.
#'
#' @export
train_nn.matrix =
    function(
        x,
        y,
        hidden_neurons = NULL,
        activations = NULL,
        output_activation = NULL,
        bias = TRUE,
        arch = NULL,
        architecture = NULL,
        early_stopping = NULL,
        epochs = 100,
        batch_size = 32,
        penalty = 0,
        mixture = 0,
        learn_rate = 0.001,
        optimizer = "adam",
        optimizer_args = list(),
        loss = "mse",
        validation_split = 0,
        device = NULL,
        verbose = FALSE,
        cache_weights = FALSE,
        initial_model = NULL,
        track_optim_path = FALSE,
        ...
    ) {
        arch = .resolve_train_architecture(architecture = architecture, arch = arch)

        act_specs = eval_act_funs({{ activations }}, {{ output_activation }})
        activations = act_specs$activations
        output_activation = act_specs$output_activation

        train_nn_impl(
            x = x,
            y = y,
            hidden_neurons = hidden_neurons,
            activations = activations,
            output_activation = output_activation,
            bias = bias,
            arch = arch,
            early_stopping = early_stopping,
            epochs = epochs,
            batch_size = batch_size,
            penalty = penalty,
            mixture = mixture,
            learn_rate = learn_rate,
            optimizer = optimizer,
            optimizer_args = optimizer_args,
            loss = loss,
            validation_split = validation_split,
            device = device,
            verbose = verbose,
            cache_weights = cache_weights,
            initial_model = initial_model,
            track_optim_path = track_optim_path,
            fit_class = "nn_fit"
        )
    }


#' @rdname gen-nn-train
#'
#' @section Data frame method:
#' When `x` is a data frame, `y` can be either a vector / factor / matrix of
#' outcomes, or a formula of the form `outcome ~ predictors` evaluated against
#' `x`. Preprocessing is handled by `hardhat::mold()`.
#'
#' @export
train_nn.data.frame =
    function(
        x,
        y,
        hidden_neurons = NULL,
        activations = NULL,
        output_activation = NULL,
        bias = TRUE,
        arch = NULL,
        architecture = NULL,
        early_stopping = NULL,
        epochs = 100,
        batch_size = 32,
        penalty = 0,
        mixture = 0,
        learn_rate = 0.001,
        optimizer = "adam",
        optimizer_args = list(),
        loss = "mse",
        validation_split = 0,
        device = NULL,
        verbose = FALSE,
        cache_weights = FALSE,
        initial_model = NULL,
        track_optim_path = FALSE,
        ...
    ) {
        arch = .resolve_train_architecture(architecture = architecture, arch = arch)

        act_specs = eval_act_funs({{ activations }}, {{ output_activation }})
        activations = act_specs$activations
        output_activation = act_specs$output_activation

        processed = if (rlang::is_formula(y)) hardhat::mold(y, x) else hardhat::mold(x, y)

        .train_nn_tab_impl(
            processed = processed,
            formula = NULL,
            hidden_neurons = hidden_neurons,
            activations = activations,
            output_activation = output_activation,
            bias = bias,
            arch = arch,
            early_stopping = early_stopping,
            epochs = epochs,
            batch_size = batch_size,
            penalty = penalty,
            mixture = mixture,
            learn_rate = learn_rate,
            optimizer = optimizer,
            optimizer_args = optimizer_args,
            loss = loss,
            validation_split = validation_split,
            device = device,
            verbose = verbose,
            cache_weights = cache_weights,
            initial_model = initial_model,
            track_optim_path = track_optim_path
        )
    }


#' @rdname gen-nn-train
#'
#' @section Formula method:
#' When `x` is a formula, `data` must be supplied as the data frame against
#' which the formula is evaluated. Preprocessing is handled by `hardhat::mold()`.
#'
#' @export
train_nn.formula =
    function(
        x,
        data,
        hidden_neurons = NULL,
        activations = NULL,
        output_activation = NULL,
        bias = TRUE,
        arch = NULL,
        architecture = NULL,
        early_stopping = NULL,
        epochs = 100,
        batch_size = 32,
        penalty = 0,
        mixture = 0,
        learn_rate = 0.001,
        optimizer = "adam",
        optimizer_args = list(),
        loss = "mse",
        validation_split = 0,
        device = NULL,
        verbose = FALSE,
        cache_weights = FALSE,
        initial_model = NULL,
        track_optim_path = FALSE,
        ...
    ) {
        arch = .resolve_train_architecture(architecture = architecture, arch = arch)

        if (missing(data) || is.null(data)) {
            cli::cli_abort("{.arg data} must be provided when using the formula interface.")
        }

        act_specs = eval_act_funs({{ activations }}, {{ output_activation }})
        activations = act_specs$activations
        output_activation = act_specs$output_activation

        processed = hardhat::mold(x, data)

        .train_nn_tab_impl(
            processed = processed,
            formula = x,
            hidden_neurons = hidden_neurons,
            activations = activations,
            output_activation = output_activation,
            bias = bias,
            arch = arch,
            early_stopping = early_stopping,
            epochs = epochs,
            batch_size = batch_size,
            penalty = penalty,
            mixture = mixture,
            learn_rate = learn_rate,
            optimizer = optimizer,
            optimizer_args = optimizer_args,
            loss = loss,
            validation_split = validation_split,
            device = device,
            verbose = verbose,
            cache_weights = cache_weights,
            initial_model = initial_model,
            track_optim_path = track_optim_path
        )
    }


#' @rdname gen-nn-train
#' @export
train_nn.default = function(x, ...) {
    cli::cli_abort(c(
        "No {.fn train_nn} method for class {.cls {class(x)}}.",
        i = "Supported classes: {.cls matrix}, {.cls data.frame}, {.cls formula}, {.cls dataset}."
    ))
}


#' Preprocessing bridge for data.frame and formula methods
#' @keywords internal
.train_nn_tab_impl =
    function(
        processed,
        formula,
        hidden_neurons,
        activations,
        output_activation,
        bias,
        arch,
        early_stopping,
        epochs,
        batch_size,
        penalty,
        mixture,
        learn_rate,
        optimizer,
        optimizer_args,
        loss,
        validation_split,
        device,
        verbose,
        cache_weights,
        initial_model = NULL,
        track_optim_path = FALSE
    ) {
        predictors = processed$predictors
        outcomes = processed$outcomes

        if (!is.matrix(predictors)) predictors = as.matrix(predictors)

        if (is.data.frame(outcomes)) {
            outcomes = if (ncol(outcomes) == 1L) outcomes[[1L]] else as.matrix(outcomes)
        } else if (!is.null(ncol(outcomes)) && ncol(outcomes) == 1L) {
            outcomes = outcomes[[1L]]
        }

        fit = train_nn_impl(
            x = predictors,
            y = outcomes,
            hidden_neurons = hidden_neurons,
            activations = activations,
            output_activation = output_activation,
            bias = bias,
            arch = arch,
            early_stopping = early_stopping,
            epochs = epochs,
            batch_size = batch_size,
            penalty = penalty,
            mixture = mixture,
            learn_rate = learn_rate,
            optimizer = optimizer,
            optimizer_args = optimizer_args,
            loss = loss,
            validation_split = validation_split,
            device = device,
            verbose = verbose,
            cache_weights = cache_weights,
            initial_model = initial_model,
            track_optim_path = track_optim_path,
            fit_class = "nn_fit_tab"
        )

        fit$blueprint = processed$blueprint
        if (!is.null(formula)) fit$formula = formula

        fit
    }


#' Shared core implementation
#'
#' @srrstats {G2.4} Explicit type conversions are applied at the y-encoding
#'   step below: `as.integer()` for factor outcomes (G2.4a), `as.numeric()`
#'   for continuous outcomes (G2.4b), `as.factor()` for character outcomes
#'   (G2.4d), and `factor(..., levels, labels)` to convert predictions back
#'   from integer codes (G2.4e).
#' @srrstats {G2.4a} Factor outcomes are encoded via explicit `as.integer()`.
#' @srrstats {G2.4b} Continuous outcomes pass through explicit `as.numeric()`.
#' @srrstats {G2.4c} Character conversion is not silently applied to data;
#'   the only character-relevant path (character outcome) goes through
#'   `as.factor()` with a diagnostic message.
#' @srrstats {G2.4d} Character outcomes are converted with explicit
#'   `as.factor()`, with a diagnostic message (see G2.9).
#' @srrstats {G2.4e} Predictions are converted from factor codes via
#'   `factor(as.integer(.), levels, labels)` using the levels recorded at
#'   training time.
#' @srrstats {G2.9} Diagnostic messages are issued for information-adding or
#'   information-losing conversions: auto-generated predictor names when
#'   `x` has no column names, and character-to-factor outcome conversion.
#' @srrstats {G2.10} Column extraction never relies on default drop
#'   behaviour: all row subsetting uses `drop = FALSE`, and single-column
#'   outcomes are extracted explicitly (`[[1L]]`) in `.train_nn_tab_impl()`.
#' @srrstats {ML4.1} `track_optim_path = TRUE` optionally retains
#'   per-epoch information on the optimizer's path, minimally including
#'   the three components named by the standard (see ML4.1a-c).
#' @srrstats {ML4.1a} A hashed representation of all model-internal
#'   parameters is recorded at each epoch (`optim_path$param_hash`),
#'   the "equivalent hashed representation" the standard allows.
#' @srrstats {ML4.1b} The per-epoch value of the loss function (and
#'   validation loss when a validation split is used) is retained in
#'   `loss_history` / `val_loss_history` on the returned object, and in
#'   `optim_path$loss` when path tracking is enabled.
#' @srrstats {ML4.1c} The information used to advance is quantified by
#'   the global gradient norm recorded at each epoch
#'   (`optim_path$grad_norm`).
#' @srrstats {ML5.0} Training returns a single model object (class
#'   `nn_fit`) containing the trained torch module plus all metadata.
#' @srrstats {ML5.0a} The returned object has its own class (`nn_fit`, with
#'   subclasses `nn_fit_tab` / `nn_fit_ds`).
#' @srrstats {ML3.5} Optimization is controlled by explicit parameters for
#'   both the search algorithm and the loss function.
#' @srrstats {ML3.5a} `optimizer` selects the search algorithm; any
#'   `torch::optim_*()` constructor is accepted, with extra arguments via
#'   `optimizer_args`.
#' @srrstats {ML3.5b} `loss` selects the loss function used to assess
#'   distance between estimates and targets.
#' @srrstats {ML3.6} Multiple search algorithms and loss functions are
#'   permitted, not a single hard-coded pair.
#' @srrstats {ML3.6a} Multiple optimizers: `"adam"`, `"sgd"`, `"rmsprop"`,
#'   and any other `torch::optim_*()` implementation by name.
#' @srrstats {ML3.6b} Multiple losses: `"mse"`, `"mae"`, `"cross_entropy"`,
#'   `"bce"`, plus arbitrary user-supplied loss functions or lambdas
#'   (validated by `.validate_loss_fn()`).
#' @keywords internal
train_nn_impl =
    function(
        x,
        y,
        hidden_neurons,
        activations = NULL,
        output_activation = NULL,
        bias = TRUE,
        arch = NULL,
        early_stopping = NULL,
        epochs = 100,
        batch_size = 32,
        penalty = 0,
        mixture = 0,
        learn_rate = 0.001,
        optimizer = "adam",
        optimizer_args = list(),
        loss = "mse",
        validation_split = 0,
        device = NULL,
        verbose = FALSE,
        cache_weights = FALSE,
        initial_model = NULL,
        track_optim_path = FALSE,
        fit_class = "nn_fit"
    ) {
        if (!requireNamespace("torch", quietly = TRUE)) {
            cli::cli_abort("Package {.pkg torch} is required but not installed.")
        }

        if (missing(hidden_neurons) || is.null(hidden_neurons) || length(hidden_neurons) == 0L) {
            hidden_neurons = integer(0L)
        }

        # ---- Input assertions ----
        check_training_args(epochs, batch_size, learn_rate, validation_split, verbose, cache_weights)
        validate_regularization(penalty, mixture)
        if (!is.matrix(x)) x = as.matrix(x)
        check_predictor_matrix(x)
        check_outcome(y, nrow(x))
        check_flag(track_optim_path, "track_optim_path")

        # ---- Warm start: inherit architecture from the initial model ----
        if (!is.null(initial_model)) {
            if (!inherits(initial_model, "nn_fit") || is.null(initial_model$model)) {
                cli::cli_abort(
                    "{.arg initial_model} must be a trained {.cls nn_fit} object (from {.fn train_nn} or {.fn load_kindling}).",
                    class = "kindling_input_error"
                )
            }
            hidden_neurons = initial_model$hidden_neurons %||% integer(0)
            activations = initial_model$activations
            output_activation = initial_model$output_activation
            arch = initial_model$arch
        }

        # ---- Device ----
        device = if (is.null(device)) get_default_device() else validate_device(device)
        if (verbose) cli::cli_alert_info("Using device: {device}")

        # ---- Input transform ----
        input_fn = if (!is.null(arch) && !is.null(arch$input_transform)) {
            rlang::as_function(arch$input_transform)
        } else {
            identity
        }

        # ---- Metadata ----
        if (is.null(colnames(x))) {
            cli::cli_inform(
                "{.arg x} has no column names: using generated names {.val V1}..{.val V{ncol(x)}}."
            )
        }
        feature_names = colnames(x) %||% paste0("V", seq_len(ncol(x)))
        response_name = names(y)[1L] %||% "y"
        is_classification = is.factor(y) || is.character(y)

        # ---- y encoding ----
        if (is_classification) {
            if (is.character(y)) {
                cli::cli_inform(
                    "Character outcome {.arg y} converted to factor with alphabetical level ordering."
                )
                y = as.factor(y)
            }
            y_levels = levels(y)
            n_classes = length(y_levels)
            y_numeric = as.integer(y)
            no_y = n_classes
        } else {
            y_levels = NULL
            n_classes = NULL
            y_numeric = if (is.matrix(y)) y else as.numeric(y)
            no_y = if (is.matrix(y)) ncol(y) else 1L
        }

        no_x = ncol(x)
        n_obs = nrow(x)

        # ---- Validation split ----
        if (validation_split > 0 && validation_split < 1) {
            n_val = floor(n_obs * validation_split)
            val_idx = sample(n_obs, n_val)
            train_idx = setdiff(seq_len(n_obs), val_idx)

            x_train = x[train_idx, , drop = FALSE]
            y_train = y_numeric[train_idx]
            x_val = x[val_idx, , drop = FALSE]
            y_val = y_numeric[val_idx]
        } else {
            x_train = x
            y_train = y_numeric
            x_val = NULL
            y_val = NULL
        }

        # ---- Build model ----
        if (!is.null(initial_model)) {
            if (initial_model$no_x != no_x || initial_model$no_y != no_y) {
                cli::cli_abort(
                    "{.arg initial_model} was trained for {initial_model$no_x} predictors / {initial_model$no_y} outputs, but the supplied data has {no_x} / {no_y}.",
                    class = "kindling_input_error"
                )
            }
        }

        arch_args = if (!is.null(arch)) {
            args = unclass(arch)
            args$input_transform = NULL
            args
        } else {
            list()
        }

        arch_env = if (!is.null(arch)) attr(arch, "env") else parent.frame()
        # model_expr = do.call(
        #     nn_module_generator,
        #     c(
        #         list(
        #             hd_neurons = hidden_neurons,
        #             no_x = no_x,
        #             no_y = no_y,
        #             activations = activations,
        #             output_activation = output_activation,
        #             bias = bias
        #         ),
        #         arch_args,
        #         .env = arch_env
        #     )
        # )
        model_expr = rlang::exec(
            nn_module_generator,

            # Arguments
            hd_neurons = hidden_neurons,
            no_x = no_x,
            no_y = no_y,
            activations = activations,
            output_activation = output_activation,
            bias = bias,

            # Executing arguments from `nn_arch()`
            # To sync up with the current environment
            !!!arch_args,
            .env = arch_env
        )

        model = if (!is.null(initial_model)) {
            # deep copy so the supplied model is left untouched
            .clone_nn_module(initial_model$model)
        } else {
            rlang::eval_tidy(model_expr)()
        }
        model$to(device = device)

        # ---- Early stopping state ----
        es_state = if (!is.null(early_stopping)) {
            if (!inherits(early_stopping, "early_stop_spec")) {
                cli::cli_abort(c(
                    "{.arg early_stopping} must be created with {.fn early_stop}.",
                    i = "Example: {.code early_stopping = early_stop(patience = 10)}."
                ))
            }
            if (early_stopping$monitor == "val_loss" && validation_split == 0) {
                cli::cli_abort(c(
                    "Early stopping on {.val val_loss} requires a validation set.",
                    i = "Set {.arg validation_split} > 0, or use {.code monitor = 'train_loss'}."
                ))
            }
            list(
                spec = early_stopping,
                best_loss = Inf,
                best_weights = NULL,
                wait = 0L,
                stopped_epoch = NA_integer_
            )
        } else {
            NULL
        }

        # ---- Tensors ----
        .make_tensor = function(mat, is_y = FALSE) {
            t = torch::torch_tensor(
                mat,
                device = device,
                dtype = if (is_y && is_classification) torch::torch_long()
                else torch::torch_float32()
            )
            if (!is_y) input_fn(t) else t
        }

        x_train_t = .make_tensor(x_train)
        y_train_t = .make_tensor(
            if (is_classification || is.matrix(y_train)) y_train else matrix(y_train, ncol = 1L),
            is_y = TRUE
        )

        if (!is.null(x_val)) {
            x_val_t = .make_tensor(x_val)
            y_val_t = .make_tensor(
                if (is_classification || is.matrix(y_val)) y_val else matrix(y_val, ncol = 1L),
                is_y = TRUE
            )
        }

        # ---- Optimizer ----
        validate_optimizer(tolower(optimizer))
        optimizer_fn = get(paste0("optim_", tolower(optimizer)), envir = asNamespace("torch"))
        # opt = do.call(optimizer_fn, c(list(params = model$parameters, lr = learn_rate), optimizer_args))
        opt = rlang::exec(
            optimizer_fn,

            # Arguments
            params = model$parameters,
            lr = learn_rate,

            # Extra arguments from `optimizer_args`
            !!!optimizer_args
        )

        # ---- Loss function ----
        loss_fn = if (is.function(loss)) {
            .validate_loss_fn(loss)
        } else if (rlang::is_formula(loss)) {
            .validate_loss_fn(rlang::as_function(loss))
        } else {
            loss_name = tolower(loss)

            if (is_classification && loss_name == "mse") {
                loss_name = "cross_entropy"
                if (verbose) cli::cli_alert("Auto-detected classification task. Using {.val cross_entropy} loss.")
            }

            switch(
                loss_name,
                mse = function(input, target) torch::nnf_mse_loss(input, target),
                mae = function(input, target) torch::nnf_l1_loss(input, target),
                cross_entropy = function(input, target) torch::nnf_cross_entropy(input, target),
                bce = function(input, target) torch::nnf_binary_cross_entropy_with_logits(input, target),
                cli::cli_abort(
                    "Unknown loss: {.val {loss_name}}.",
                    i = "Use one of {.val mse}, {.val mae}, {.val cross_entropy}, {.val bce}, or supply a {.cls function}."
                )
            )
        }

        # ---- Training loop ----
        loss_history = numeric(epochs)
        val_loss_history = if (!is.null(x_val)) numeric(epochs) else NULL
        opt_grad_norm = if (track_optim_path) numeric(epochs) else NULL
        opt_param_hash = if (track_optim_path) character(epochs) else NULL
        n_batches = ceiling(nrow(x_train) / batch_size)

        for (epoch in seq_len(epochs)) {
            model$train()
            epoch_loss = 0
            idx = sample(nrow(x_train))

            for (batch in seq_len(n_batches)) {
                start_i = (batch - 1L) * batch_size + 1L
                end_i = min(batch * batch_size, nrow(x_train))
                batch_idx = idx[start_i:end_i]

                x_batch = x_train_t[batch_idx, ]
                y_batch = y_train_t[batch_idx]

                opt$zero_grad()
                y_pred = model(x_batch)
                batch_loss = loss_fn(y_pred, y_batch)
                reg_loss = regularizer(model, penalty, mixture)
                total_loss = batch_loss + reg_loss
                total_loss$backward()
                opt$step()

                epoch_loss = epoch_loss + total_loss$item()
            }

            loss_history[epoch] = epoch_loss / n_batches

            # ---- Optimizer-path tracking ----
            if (track_optim_path) {
                g2 = 0
                for (p in model$parameters) {
                    g = p$grad
                    if (!is.null(g) && g$numel() > 0) {
                        g2 = g2 + sum(as.numeric(g$cpu())^2)
                    }
                }
                opt_grad_norm[epoch] = sqrt(g2)
                opt_param_hash[epoch] = rlang::hash(
                    lapply(model$parameters, function(p) as.numeric(p$cpu()))
                )
            }

            # ---- Validation ----
            if (!is.null(x_val)) {
                model$eval()
                torch::with_no_grad({
                    y_val_pred = model(x_val_t)
                    val_loss = loss_fn(y_val_pred, y_val_t)
                    val_loss_history[epoch] = val_loss$item()
                })
            }

            # ---- Verbose ----
            if (verbose && (epoch %% max(1L, epochs %/% 10L) == 0L || epoch == epochs)) {
                # msg = glue::glue(
                #     "Epoch {epoch}/{epochs} - Loss: {round(loss_history[epoch], 4)}"
                # )
                msg = sprintf("Epoch %d/%d - Loss: %.4f", epoch, epochs, round(loss_history[epoch], 4))
                if (!is.null(val_loss_history))
                    # msg = glue::glue("{msg} - Val Loss: {round(val_loss_history[epoch], 4)}")
                    sprintf("Epoch {epoch}/{epochs} - Loss: {round(loss_history[epoch], 4)}")

                message(msg)
            }

            # ---- Early stopping check ----
            if (!is.null(es_state)) {
                monitored = if (es_state$spec$monitor == "val_loss") {
                    val_loss_history[epoch]
                } else {
                    loss_history[epoch]
                }

                if (monitored < es_state$best_loss - es_state$spec$min_delta) {
                    es_state$best_loss = monitored
                    es_state$wait = 0L
                    if (es_state$spec$restore_best_weights) {
                        es_state$best_weights = lapply(
                            model$parameters,
                            function(p) p$detach()$clone()
                        )
                    }
                } else {
                    es_state$wait = es_state$wait + 1L
                    if (es_state$wait >= es_state$spec$patience) {
                        es_state$stopped_epoch = epoch
                        if (verbose) cli::cli_alert_warning(
                            "Early stopping at epoch {epoch}. Best {es_state$spec$monitor}: {round(es_state$best_loss, 4)}."
                        )
                        break
                    }
                }
            }
        }

        # ---- Restore best weights ----
        if (!is.null(es_state) && es_state$spec$restore_best_weights && !is.null(es_state$best_weights)) {
            params = model$parameters
            torch::with_no_grad({
                for (i in seq_along(params)) {
                    params[[i]]$set_data(es_state$best_weights[[i]])
                }
            })
            if (verbose) {
                best_ep = if (!is.na(es_state$stopped_epoch)) {
                    es_state$stopped_epoch - es_state$spec$patience
                } else {
                    epoch
                }
                cli::cli_alert_info("Restored best weights from epoch {best_ep}.")
            }
        }

        # ---- Trim histories to actual epochs run ----
        actual_epochs = if (!is.null(es_state) && !is.na(es_state$stopped_epoch)) {
            es_state$stopped_epoch
        } else {
            epochs
        }
        loss_history = loss_history[seq_len(actual_epochs)]
        val_loss_history = if (!is.null(val_loss_history)) val_loss_history[seq_len(actual_epochs)] else NULL
        stopped_epoch = if (!is.null(es_state) && !is.na(es_state$stopped_epoch)) {
            es_state$stopped_epoch
        } else {
            NA_integer_
        }
        optim_path = if (track_optim_path) {
            data.frame(
                epoch = seq_len(actual_epochs),
                loss = loss_history,
                grad_norm = opt_grad_norm[seq_len(actual_epochs)],
                param_hash = opt_param_hash[seq_len(actual_epochs)],
                stringsAsFactors = FALSE
            )
        } else {
            NULL
        }

        # ---- Fitted values ----
        model$eval()
        x_full_t = .make_tensor(x)
        fitted_tensor = torch::with_no_grad(model(x_full_t))

        fitted_values = if (is_classification) {
            fitted_probs = torch::nnf_softmax(fitted_tensor, dim = 2L)
            fitted_classes = torch::torch_argmax(fitted_probs, dim = 2L)
            factor(
                as.integer(fitted_classes$cpu()),
                levels = seq_along(y_levels),
                labels = y_levels
            )
        } else {
            convert = as.matrix(fitted_tensor$cpu())
            if (no_y == 1L) {
                as.vector(convert)
            } else {
                convert
            }
        }

        # ---- Weight caching ----
        # For visualizing weight distribution
        # Allow `cache_weights` to generate
        cached_weights = if (cache_weights) {
            tryCatch(
                lapply(model$parameters, function(p) as.matrix(p$cpu())),
                error = function(e) {
                    cli::cli_warn("Weight caching failed: {conditionMessage(e)}")
                    NULL
                }
            )
        } else {
            NULL
        }

        structure(
            list(
                model = model,
                fitted = fitted_values,
                loss_history = loss_history,
                val_loss_history = val_loss_history,
                optim_path = optim_path,
                n_epochs = actual_epochs,
                stopped_epoch = stopped_epoch,
                hidden_neurons = hidden_neurons,
                activations = activations,
                output_activation = output_activation,
                penalty = penalty,
                mixture = mixture,
                feature_names = feature_names,
                response_name = response_name,
                no_x = no_x,
                no_y = no_y,
                is_classification = is_classification,
                y_levels = y_levels,
                n_classes = n_classes,
                device = device,
                cached_weights = cached_weights,
                arch = arch
            ),
            class = unique(c(fit_class, "nn_fit"))
        )
    }

#' Predict from a trained neural network
#'
#' @description
#' Generate predictions from an `"nn_fit"` object produced by [train_nn()].
#'
#' Three S3 methods are registered:
#'
#' - `predict.nn_fit()` — base method for `matrix`-trained models.
#' - `predict.nn_fit_tab()` — extends the base method for tabular fits; runs new
#'   data through `hardhat::forge()` before predicting.
#' - `predict.nn_fit_ds()` — extends the base method for torch `dataset` fits.
#'
#' @param object A fitted model object returned by [train_nn()].
#' @param newdata New predictor data. Accepted forms depend on the method:
#'   - `predict.nn_fit()`: a numeric `matrix` or coercible object.
#'   - `predict.nn_fit_tab()`: a `data.frame` with the same columns used during
#'     training; preprocessing is applied automatically via `hardhat::forge()`.
#'   - `predict.nn_fit_ds()`: a `torch` `dataset`, numeric `array`, `matrix`, or
#'     `data.frame`.
#'   If `NULL`, the cached fitted values from training are returned (not
#'   available for `type = "prob"`).
#' @param new_data Legacy alias for `newdata`. Retained for compatibility.
#' @param type Character. Output type:
#'   - `"response"` (default): predicted class labels (factor) for
#'     classification, or a numeric vector / matrix for regression.
#'   - `"prob"`: a numeric matrix of class probabilities (classification only).
#' @param ... Currently unused; reserved for future extensions.
#'
#' @return
#' - **Regression**: a numeric vector (single output) or matrix (multiple outputs).
#' - **Classification**, `type = "response"`: a factor with levels matching those
#'   seen during training.
#' - **Classification**, `type = "prob"`: a numeric matrix with one column per
#'   class, columns named by class label.
#'
#' @seealso [train_nn()]
#' @name gen-nn-predict
#' @export
predict.nn_fit =
    function(
        object,
        newdata = NULL,
        new_data = NULL,
        type = "response",
        ...
    ) {
        if (!requireNamespace("torch", quietly = TRUE)) {
            cli::cli_abort("Package {.pkg torch} is required but not installed.")
        }

        if (!type %in% c("response", "prob")) {
            cli::cli_abort("{.arg type} must be one of {.val response} or {.val prob}.")
        }

        newdata = .resolve_predict_newdata(newdata = newdata, new_data = new_data)

        device = object$device
        input_fn = if (!is.null(object$arch) && !is.null(object$arch$input_transform)) {
            rlang::as_function(object$arch$input_transform)
        } else {
            identity
        }

        # Early return is a must, when `newdata` / `new_data` is not used
        # Do not attempt to use `type = "prob"` when classification is not applied
        if (is.null(newdata)) {
            if (type == "prob" && object$is_classification) {
                cli::cli_abort("Cannot compute probabilities without {.arg newdata}. Use fitted values instead.")
            }
            if (type == "prob" && !object$is_classification) {
                cli::cli_abort("{.arg type = 'prob'} is only available for classification models.")
            }
            return(object$fitted)
        }

        if (!is.matrix(newdata)) newdata = as.matrix(newdata)
        check_newdata_matrix(newdata)

        x_new_t = input_fn(torch::torch_tensor(newdata, dtype = torch::torch_float32(), device = device))
        object$model$eval()
        pred_tensor = torch::with_no_grad(object$model(x_new_t))

        predictions = if (object$is_classification) {
            probs = torch::nnf_softmax(pred_tensor, dim = 2L)

            if (type == "prob") {
                prob_matrix = as.matrix(probs$cpu())
                colnames(prob_matrix) = object$y_levels
                prob_matrix
            } else {
                factor(
                    as.integer(torch::torch_argmax(probs, dim = 2L)$cpu()),
                    levels = seq_along(object$y_levels),
                    labels = object$y_levels
                )
            }
        } else {
            if (type == "prob") {
                cli::cli_abort("{.arg type = 'prob'} is only available for classification models.")
            }

            convert = as.matrix(pred_tensor$cpu())
            if (object$no_y == 1L) {
                as.vector(convert)
            } else {
                convert
            }
        }

        predictions
    }


#' @rdname gen-nn-predict
#' @export
predict.nn_fit_tab =
    function(
        object,
        newdata = NULL,
        new_data = NULL,
        type = "response",
        ...
    ) {
        newdata = .resolve_predict_newdata(newdata = newdata, new_data = new_data)

        if (!is.null(newdata) && !is.null(object$blueprint)) {
            processed = hardhat::forge(newdata, object$blueprint)
            newdata = as.matrix(processed$predictors)
        }

        NextMethod()
    }


#' @keywords internal
#' @export
`$.nn_fit` = function(x, name) {
    if (name %in% names(x)) return(x[[name]])
    attr(x, name, exact = TRUE)
}

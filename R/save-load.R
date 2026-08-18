#' Save and reload trained kindling models
#'
#' @description
#' `save_kindling()` writes a trained kindling model (an `nn_fit`,
#' `ffnn_fit`, or `rnn_fit` object) to a file, and `load_kindling()`
#' restores it. Base [saveRDS()] is **not** appropriate for these objects:
#' the underlying `torch::nn_module` holds external pointers into
#' LibTorch that do not survive ordinary R serialization. These functions
#' split the object instead -- the torch module is serialized with
#' [torch::torch_serialize()] and everything else with R's serializer --
#' so the reloaded model is fully functional.
#'
#' The reloaded model lives on the CPU (`$device` is set to `"cpu"`),
#' regardless of the device it was trained on; move it with
#' `object$model$to(device = ...)` if needed. Reloaded fits can be used
#' directly with [predict()], and re-submitted to [train_nn()] via its
#' `initial_model` argument to continue training.
#'
#' Note for custom architectures: the *instantiated* module is saved, so
#' prediction and continued training work after reload even for
#' [nn_arch()]-based models; only re-building the architecture from
#' scratch would require the original constructor objects.
#'
#' @param object A trained model of class `nn_fit`, `ffnn_fit`, or
#'   `rnn_fit`.
#' @param path File path to write to / read from.
#'
#' @return `save_kindling()` returns `path` invisibly; `load_kindling()`
#'   returns the restored model object.
#'
#' @examples
#' \donttest{
#' if (torch::torch_is_installed()) {
#'     fit = train_nn(
#'         x = as.matrix(iris[, 2:4]),
#'         y = iris$Sepal.Length,
#'         hidden_neurons = 8,
#'         epochs = 5
#'     )
#'
#'     path = tempfile(fileext = ".rds")
#'     save_kindling(fit, path)
#'
#'     fit2 = load_kindling(path)
#'     head(predict(fit2, newdata = as.matrix(iris[, 2:4])))
#'
#'     # continue training from the reloaded model
#'     fit3 = train_nn(
#'         x = as.matrix(iris[, 2:4]),
#'         y = iris$Sepal.Length,
#'         initial_model = fit2,
#'         epochs = 5
#'     )
#'
#'     unlink(path)
#' }
#' }
#'
#' @srrstats {ML5.2c} `saveRDS()` is not appropriate for torch-backed
#'   model objects (external pointers), so these dedicated save/load
#'   functions are provided and demonstrated with example code.
#' @srrstats {ML5.2b} The examples above document how to save and re-load
#'   trained models for re-use, including re-submission to `train_nn()`
#'   via `initial_model` (ML3.1).
#'
#' @seealso [train_nn()] (`initial_model` argument) for continuing
#'   training from a reloaded model.
#' @name kindling-save-load
#' @export
save_kindling = function(object, path) {
    if (!inherits(object, c("nn_fit", "ffnn_fit", "rnn_fit")) || is.null(object$model)) {
        cli::cli_abort(
            "{.arg object} must be a trained kindling model ({.cls nn_fit}, {.cls ffnn_fit}, or {.cls rnn_fit}).",
            class = "kindling_input_error"
        )
    }
    if (!is.character(path) || length(path) != 1L) {
        cli::cli_abort(
            "{.arg path} must be a single file path.",
            class = "kindling_input_error"
        )
    }

    # serialize a CPU copy of the module for portability, restoring the
    # live model's device afterwards ($to() moves in place)
    orig_device = object$device %||% "cpu"
    if (!identical(orig_device, "cpu")) {
        object$model$to(device = "cpu")
        on.exit(object$model$to(device = orig_device), add = TRUE)
    }
    model_raw = torch::torch_serialize(object$model)

    fit = object
    fit$model = NULL
    fit$device = "cpu"

    saveRDS(
        list(
            model_raw = model_raw,
            fit = fit,
            kindling_version = as.character(utils::packageVersion("kindling"))
        ),
        path
    )
    invisible(path)
}

#' @rdname kindling-save-load
#' @export
load_kindling = function(path) {
    payload = tryCatch(
        suppressWarnings(readRDS(path)),
        error = function(e) {
            cli::cli_abort(
                c(
                    "Failed to read {.path {path}}.",
                    x = conditionMessage(e)
                ),
                class = "kindling_input_error"
            )
        }
    )
    if (!is.list(payload) || is.null(payload$model_raw) || is.null(payload$fit)) {
        cli::cli_abort(
            "{.path {path}} was not written by {.fn save_kindling}.",
            class = "kindling_input_error"
        )
    }

    fit = payload$fit
    fit$model = torch::torch_load(payload$model_raw)
    # refresh module-internal tensor caches (e.g. the flattened weight
    # lists of recurrent layers, whose pointers do not survive
    # serialization): $to() re-applies over all tensors and rebuilds them
    fit$model$to(device = "cpu")
    fit
}

#' Deep-copy a torch module via an in-memory serialization roundtrip
#' @noRd
.clone_nn_module = function(module) {
    torch::torch_load(torch::torch_serialize(module))
}

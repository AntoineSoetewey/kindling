#' @keywords internal
.onLoad = function(libname, pkgname) {
    vctrs::s3_register("vip::vi_model", "ffnn_fit")
    make_kindling()
}



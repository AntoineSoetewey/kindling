# Local replication of pkgcheck's fns_have_return_vals and fns_have_exs
# checks (see ropensci-review-tools/pkgcheck R/check-fns-have-*.R).
# Run from the package root:  Rscript dev/pkgcheck-followup/verify-pkgcheck.R
rd_files <- list.files("man", pattern = "\\.Rd$", full.names = TRUE)

get1tag <- function(rd, what) {
    tags <- unlist(lapply(rd, function(i) attr(i, "Rd_tag")))
    index <- grep(paste0(what, "$"), tags)
    if (length(index) == 0L) return("")
    unlist(lapply(rd[index], function(j) paste0(unlist(j), collapse = "")))
}

rows <- lapply(rd_files, function(f) {
    x <- tools::parse_Rd(f, permissive = TRUE)
    ex <- get1tag(x, "examples")
    list(
        file    = basename(f),
        name    = get1tag(x, "name")[1],
        docType = paste(get1tag(x, "docType"), collapse = ""),
        value   = paste(get1tag(x, "value"), collapse = ""),
        keyword = get1tag(x, "keyword"),
        n_ex    = sum(nzchar(ex))
    )
})

# --- check 1: return values ---
fail_val <- Filter(function(r) {
    !nzchar(r$docType) &&
        !any(r$keyword %in% c("datasets", "internal")) &&
        !nzchar(r$value)
}, rows)

# --- check 2: examples ---
fail_ex <- Filter(function(r) {
    !any(r$keyword %in% c("internal", "datasets")) &&
        !(r$docType %in% c("package", "data")) &&
        r$n_ex == 0L
}, rows)

cat("Rd files scanned:", length(rows), "\n\n")
cat("FAIL - no documented return value:",
    if (length(fail_val)) paste(vapply(fail_val, `[[`, "", "name"), collapse = ", ") else "(none)", "\n")
cat("FAIL - no examples:",
    if (length(fail_ex)) paste(vapply(fail_ex, `[[`, "", "name"), collapse = ", ") else "(none)", "\n")

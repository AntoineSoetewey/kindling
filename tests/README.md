# kindling test suite

Regular tests run with `devtools::test()` / `R CMD check` and skip
automatically when torch's backend (LibTorch/Lantern) is not installed
(`torch::torch_is_installed()`).

## Extended tests

Extended tests (`test-srr-extended.R`) are switched on by an environment
variable, per rOpenSci statistical standard **G5.10**:

```sh
KINDLING_EXTENDED_TESTS=true Rscript -e 'devtools::test()'
```

They repeat the parameter-recovery correctness tests under multiple random
seeds (standard **G5.6b**). Requirements: a working torch installation,
CPU only, no additional data or downloads, roughly 30–60 s extra runtime.
No artefacts are produced.

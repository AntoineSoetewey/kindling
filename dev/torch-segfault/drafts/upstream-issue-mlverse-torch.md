# DRAFT -- issue for mlverse/torch

**DO NOT FILE YET.** Gated on obtaining an actual reproduction or a backtrace
from the affected rOpenSci host (see NOTES.md §5). Every environment we can
access installs successfully, so as of 2026-08-02 this report would have no
actionable content. Fill every `TODO` placeholder from the server diagnostic
log (`server-repro/`) before considering filing, and delete this header.

## Title

`install_torch()` segfaults at process exit during `docker build` after
completing the installation

## Body

---

### Summary

During a `docker build` of rOpenSci's pkgcheck image (base
`eddelbuettel/r2u:24.04`, root, torch installed as the r2u binary
`r-cran-torch 0.17.0`), the step

```dockerfile
RUN Rscript -e 'torch::install_torch()'
```

downloads and unpacks libtorch and lantern successfully, then the R process
dies with a segfault at (or near) exit. Because the RUN step exits non-zero,
docker discards the layer, so the image ends up without torch despite the
installation having completed on disk.

The crash is environment-specific: the identical Dockerfile builds cleanly
on GitHub Actions runners (e.g.
https://github.com/ropensci-review-tools/pkgcheck/actions/runs/30232503908,
step `#23`), and in `rocker/tidyverse:latest` / `eddelbuettel/r2u:24.04`
containers. It reproduces on the host described below.

- First reported in ropensci/software-review#784 by @mpadge.

### Reproduction

TODO: confirm minimal reproducing Dockerfile (candidate below, trimmed from
the diagnostic build that reproduced it):

```dockerfile
FROM eddelbuettel/r2u:24.04
RUN install2.r torch
RUN Rscript -e 'torch::install_torch()'
```

```sh
docker build --progress=plain --no-cache .
```

### Observed vs expected

- Expected: `install_torch()` returns invisibly TRUE, `Rscript` exits 0.
- Observed: installation completes (files present under
  `torch::torch_install_path()` when checked in the same layer), then the
  process segfaults. Exit code 139. TODO: paste exact output tail.

### Backtrace

TODO: paste `bt full` / `thread apply all bt` from the gdb run of the
diagnostic build.

### Environment (affected host)

- torch: 0.17.0 (r-cran-torch 0.17.0-1.ca2404.1, r2u)
- libtorch: 2.8.0+cpu (libtorch-shared-with-deps-2.8.0+cpu.zip)
- lantern: 0.17.0+cpu+x86_64-Linux
- R: 4.6.1
- OS (container): Ubuntu 24.04
- Host kernel (`uname -a`): TODO
- Docker / BuildKit: TODO (`docker version`)
- CPU (`lscpu`, AVX flags): TODO
- `install_torch_sitrep()` output: TODO

### Notes

- Environments where it does NOT reproduce: GitHub Actions ubuntu-latest
  (both as `docker build` and inside containers), gdb runs there end with
  `exited normally`.
- The failure mode (completed install + crash at exit) suggests teardown of
  loaded native libraries rather than the download/unpack path.

---

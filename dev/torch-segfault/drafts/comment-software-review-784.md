# POSTED 2026-08-02 -- https://github.com/ropensci/software-review/issues/784#issuecomment-5158034520

@mpadge Following up on the `install_torch()` segfault (your comment of July 16), ahead of our August return. TL;DR: **we made a serious attempt and cannot reproduce the segfault anywhere we have access to -- including in pkgcheck's own CI, which has rebuilt your exact Dockerfile successfully three times since the merge.** We think the remaining distinguishing variable is the rOpenSci build host itself, so we need one thing from you: the failing build's log, or one run of a diagnostic build we prepared (links below). We've also opened ropensci-review-tools/pkgcheck#397 so the weekly rebuild no longer depends on this step succeeding.

### What we tested (all negative)

1. **Clean containers** (as you suggested): `rocker/tidyverse:latest` and `eddelbuettel/r2u:24.04`, fresh `install_torch()` runs, plain and under `gdb` ([run 1](https://github.com/joshuamarie/kindling/actions/runs/29558274935), [run 2](https://github.com/joshuamarie/kindling/actions/runs/29557240404)). Every run downloads libtorch 2.8.0+cpu (170.6 MB) + lantern 0.17.0 (5.7 MB) and exits 0; gdb reports `exited normally`, `No stack.` Note the r2u leg has bspm enabled, so torch there is the same `r-cran-torch` apt binary your image uses.

2. **A real `docker build`** (the actual failing context, which the first attempt didn't cover): a four-variant bisection from `eddelbuettel/r2u:24.04` -- faithful replay of your Dockerfile's torch-relevant steps (bspm block, r2u binary arrow+torch, `ARROW_S3`, `install_arrow()` then `install_torch()`), a no-arrow variant, a torch-from-P3M variant (bspm disabled), and a fresh-install-under-gdb variant. [All four pass](https://github.com/AntoineSoetewey/kindling/actions/runs/30748491813): `install_torch()` exit code 0 everywhere, `install_torch_sitrep()` healthy, `torch_tensor()` works in the built images, gdb again `exited normally`. (One job needed a rerun after a transient r2u mirror timeout -- unrelated to torch.) Dockerfiles and full logs: [dev/torch-segfault](https://github.com/AntoineSoetewey/kindling/tree/torch-segfault-followup/dev/torch-segfault).

3. **Most tellingly: pkgcheck's own `docker.yaml` CI** builds your complete, unmodified Dockerfile weekly (Mondays 00:00 UTC) and has passed three times since #393 was merged, with the `install_torch()` step genuinely executing (downloads visible in the public logs, ~10 s, exit 0): [Jul 16](https://github.com/ropensci-review-tools/pkgcheck/actions/runs/29487664312), [Jul 20](https://github.com/ropensci-review-tools/pkgcheck/actions/runs/29712935423), [Jul 27](https://github.com/ropensci-review-tools/pkgcheck/actions/runs/30232503908). So `ghcr.io/ropensci-review-tools/pkgcheck:latest` currently ships with torch fully installed.

We also checked mlverse/torch for existing reports: no open or recent issue matches an `install_torch()` segfault (closest is mlverse/torch#271, from 2020, closed). We have an issue draft ready, but we don't want to file "someone saw a segfault we can't show" -- we'd rather file it with your backtrace attached.

### What we'd need from you

Since every public environment passes, the crash looks specific to the host where your failing build ran (kernel, docker/BuildKit version, seccomp, storage driver, CPU flags, ...). Could you either:

- share the tail of the failing `docker build` output from the server (the `install_torch()` step and anything after it), plus `docker version`, `uname -a` and `lscpu`; **or**
- run the one-command diagnostic build we prepared: [dev/torch-segfault/server-repro](https://github.com/AntoineSoetewey/kindling/tree/torch-segfault-followup/dev/torch-segfault/server-repro). It never fails, and produces exit codes, filesystem state, a gdb backtrace of a fresh install, `install_torch_sitrep()` output and environment info in a single log.

Your "installed but failed during cleanup" reading fits docker-build semantics, by the way: if the R process segfaults at exit *after* unpacking completes, the `RUN` step returns 139 and docker discards the otherwise complete layer -- which would look exactly like "it never got installed in the container".

### Making the weekly rebuild robust regardless

Since the server has crossed two Tuesday rebuilds since your manual patch, we've opened ropensci-review-tools/pkgcheck#397: it keeps `install_torch()` as the primary path but tolerates an exit-time crash (so a completed install isn't discarded with the layer), records `install_torch_sitrep()` in the build log, and sets `TORCH_INSTALL=1` -- your manual patch, made permanent as a runtime fallback. Happy to adjust it however you prefer.

Per your request we've kept detailed process notes with the skill/blog-post follow-up in mind: [dev/torch-segfault/NOTES.md](https://github.com/AntoineSoetewey/kindling/blob/torch-segfault-followup/dev/torch-segfault/NOTES.md).

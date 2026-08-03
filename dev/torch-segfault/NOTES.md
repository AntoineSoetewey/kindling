# `torch::install_torch()` segfault investigation -- working notes

Status: **RESOLVED, 2026-08-03.** The bot check on #784 is
[green again](https://github.com/ropensci/software-review/issues/784#issuecomment-5167023176)
(coverage 88.7%, R CMD check clean) after @mpadge rebuilt and redeployed the
bot server with `ENV TORCH_INSTALL="1"` baked into the pkgcheck image
([pkgcheck#398](https://github.com/ropensci-review-tools/pkgcheck/pull/398),
adopting the core of our closed
[pkgcheck#397](https://github.com/ropensci-review-tools/pkgcheck/pull/397)).
The crash was never reproducible in any public environment (docker-build
matrix 2026-08-02: 4/4 negative), its root cause remains unconfirmed (no
server log/backtrace was received), and the upstream issue template stays
unfiled by design. Temporary repro workflows removed; this directory is the
preserved process record for the rOpenSci skill / blog-post follow-up.
Last updated: 2026-08-03.

Public follow-ups posted 2026-08-02:
[#784 comment](https://github.com/ropensci/software-review/issues/784#issuecomment-5158034520),
[kindling#34 cross-ref](https://github.com/joshuamarie/kindling/issues/34#issuecomment-5158035374).

2026-08-03 developments:

- @mpadge's [closing comment on #397](https://github.com/ropensci-review-tools/pkgcheck/pull/397#issuecomment-5165052653)
  reports that even after the build-time `install_torch()`, `library(torch)`
  interactively prompted to download "additional software". Note for the
  record: the two files in his paste are
  `libtorch-shared-with-deps-2.8.0+cpu.zip` and
  `lantern-0.17.0+cpu+x86_64-Linux.zip` -- i.e. the *same* full runtime pair
  `install_torch()` installs, not extra tools. `library(torch)` re-prompting
  means torch found no (valid) installation at load time, consistent with
  the build-time layer having been lost (segfault -> discarded layer) on the
  server build. His "hardware probing" speculation doesn't match the
  installer's logic (the cpu/cuda choice only selects the download URL).
- Holding label removed by new EiC @adamhsparks, who re-triggered the bot
  check on #784 at 03:00 UTC. That check ran **before** the #398 fix and
  failed with the torch-missing signature (coverage 39.4%, R CMD check
  build failure) -- as predicted in §3 (two Tuesday server rebuilds had
  passed since the manual patch).
- pkgcheck image rebuild with #398 in flight:
  [run 30805282686](https://github.com/ropensci-review-tools/pkgcheck/actions/runs/30805282686).
  The review-bot server picks the change up at its own rebuild (Tuesdays
  00:01 UTC, i.e. 2026-08-04), unless redeployed manually before that.
- Process lesson recorded: upstream contributions should be minimal and
  terse -- small diff, short PR body ("too Claude-verbose" feedback).

These notes document the full process, as requested by @mpadge in
[ropensci/software-review#784](https://github.com/ropensci/software-review/issues/784)
(comment of 2026-07-17: "please document your general processes as thoroughly
as possible", with a view to an rOpenSci skill and a co-authored blog post).

## 1. The problem

- kindling imports `{torch}`, which needs LibTorch + Lantern installed at
  first use. Our pkgcheck PR
  [ropensci-review-tools/pkgcheck#393](https://github.com/ropensci-review-tools/pkgcheck/pull/393)
  (merged 2026-07-16) added `RUN Rscript -e 'torch::install_torch()'` at line
  321 of the pkgcheck Dockerfile, right after `arrow::install_arrow()`
  (line 318).
- @mpadge reported
  ([#784, 2026-07-16 14:24 UTC](https://github.com/ropensci/software-review/issues/784#issuecomment-3079390945)
  -- adjust anchor when quoting) that `install_torch()` "fails with a system
  segfault" when the rOpenSci image is built, that he temporarily rebuilt
  with `TORCH_INSTALL=1` instead, and that the system auto-rebuilds every
  Tuesday 00:01 UTC, after which the manual patch is lost. He asked us to
  (1) reproduce in a clean container and (2) report upstream to mlverse/torch
  if reproducible. His hypothesis: the installation itself completes, and the
  crash happens "somewhere in the cleanup process".

## 2. Facts established (all verifiable from public logs)

### 2.1 First reproduction attempt (containers, not docker build) -- negative

Workflow `torch-segfault-repro.yml` (kindling PR #35, commits 167da8b,
3a4ceaf), matrix `rocker/tidyverse:latest` x `eddelbuettel/r2u:24.04`, ran
twice on 2026-07-17:

- https://github.com/joshuamarie/kindling/actions/runs/29558274935
- https://github.com/joshuamarie/kindling/actions/runs/29557240404

All four jobs: `install_torch()` downloads libtorch 2.8.0+cpu (170.6 MB) and
lantern 0.17.0+cpu (5.7 MB) and exits 0. Under gdb: `[Inferior 1 (process N)
exited normally]`, `No stack.` Torch package version: 0.17.0, R 4.6.1,
Ubuntu 24.04. Artifacts preserved in `./artifacts/`.

Three diagnostic flaws in that workflow (all fixed in the new one, see §4):

1. `find / -newer /tmp` compared against `/tmp`'s constantly-moving mtime, so
   the sweep found nothing but its own output file. Fixed with a dedicated
   marker file created before the install.
2. The "was libtorch extracted?" check looked at
   `tools::R_user_dir("torch", "cache")`, which is **not** where torch
   installs. The real target is `torch::torch_install_path()` (defaults to
   the torch package directory, or `TORCH_HOME` if set); `exists: FALSE`
   there was not an anomaly. `torch::install_torch_sitrep()` (exported since
   torch 0.17.0) is the proper state report.
3. The gdb run was a *second* `install_torch()` invocation after a successful
   first one; with `reinstall = FALSE` it skips download/unpack, so gdb
   mostly exercised the load-verification path (torch 0.17.0's
   `torch_is_installed()` spawns a subprocess running `torch_tensor(1)` --
   the vforked children visible in the gdb logs), not a clean install.

One correction to our own earlier framing: in the r2u leg, bspm is enabled in
the base image, so `install.packages("torch")` was intercepted and installed
the **same `r-cran-torch` apt binary** the pkgcheck image uses (bspm 0.5.7
visible in the job's sessionInfo). The "our repro installs torch differently
than pkgcheck" hypothesis was therefore already half-tested and negative; the
remaining untested difference was the `docker build` context itself.

### 2.2 pkgcheck's own CI builds the exact Dockerfile -- and passes, weekly

This is the decisive finding. The pkgcheck repo's `docker.yaml` workflow
builds the **real, complete Dockerfile** as a genuine `docker build` (buildx,
root, no layer cache on ephemeral runners) and pushes to
`mpadge/pkgcheck:latest` + `ghcr.io/ropensci-review-tools/pkgcheck:latest`,
on a `cron: "0 0 * * 1"` schedule (Mondays 00:00 UTC). Three builds have run
since #393 was merged, and all three **succeeded**, with step
`#23 RUN Rscript -e 'torch::install_torch()'` genuinely executing (downloads
visible in the logs, ~10 s, exit 0):

| date (UTC) | trigger | run | torch step |
|---|---|---|---|
| 2026-07-16 09:34 | push (post-#393) | [29487664312](https://github.com/ropensci-review-tools/pkgcheck/actions/runs/29487664312) | `#23 DONE 11.4s` |
| 2026-07-20 02:37 | schedule | [29712935423](https://github.com/ropensci-review-tools/pkgcheck/actions/runs/29712935423) | downloads OK, build success |
| 2026-07-27 02:34 | schedule | [30232503908](https://github.com/ropensci-review-tools/pkgcheck/actions/runs/30232503908) | `#23 DONE 10.3s` |

In the same logs: torch enters the image as `r-cran-torch 0.17.0-1.ca2404.1`
from r2u (apt), and `install_torch()` fetches
`libtorch-shared-with-deps-2.8.0+cpu.zip` (170.6 MB) +
`lantern-0.17.0+cpu+x86_64-Linux.zip` (5.7 MB).

Consequence: **the published pkgcheck images currently contain a working
torch installation.** The recipe is not broken; something about the host
where @mpadge's failing build ran (the rOpenSci server, which rebuilds
Tuesdays 00:01 UTC -- a separate pipeline from the GHA one) is the
distinguishing variable: kernel, docker/BuildKit version, seccomp profile,
storage driver, CPU (e.g. AVX support), memory limits, ...

Full build logs (~2 MB each) saved locally outside the repo in
`~/Documents/kindling-torch-segfault-diagnostics/` (GHA log retention is
90 days).

### 2.3 No matching upstream issue

Searched mlverse/torch issues for `install_torch segfault` and
`segfault in:title` (2026-08-02): nothing matching an `install_torch()`
crash. Closest hits are historic/unrelated: #271 (2020, GHA segfault,
closed), #1218/#1219 (test-suite segfaults, closed), #1432 (layout-overload
segfault, unrelated). Nothing to subscribe to; an upstream report would be
new -- but without a reproduction or backtrace we have nothing actionable to
file yet (see §5).

### 2.4 The mechanism that would explain "installed, yet not installed"

@mpadge: "the initial `install_torch()` actually did install, but failed
somewhere in the cleanup process". This fits docker-build semantics: if the
R process segfaults **at exit**, after the files are fully unpacked, the
`RUN` step still returns exit 139, docker discards the layer, and the
completed installation is thrown away -- "so it never got installed in the
container". This informs the remediation in §6: tolerate an exit-time crash
so a completed install is kept, verify state in a fresh process, and keep
`TORCH_INSTALL=1` as the runtime fallback.

## 3. Timeline of rebuilds vs. the manual patch

- GHA image (public registries): rebuilt Mondays; last success 2026-07-27;
  next 2026-08-03. Healthy, torch installed.
- rOpenSci server (the one the review bot uses): rebuilds Tuesdays 00:01
  UTC. Since the manual `TORCH_INSTALL=1` patch of 2026-07-16, the rebuilds
  of **2026-07-21 and 2026-07-28 have passed**, so per @mpadge's own warning
  the server environment is presumably no longer patched. Whether its weekly
  build fails at the torch step (leaving a stale image) or something else
  happens is only observable from that host. Per his request, we must ping
  him before triggering bot checks -- or better, land the robustness fix
  (§6) so this stops mattering.
- kindling's own CI is unaffected: our `pkgcheck.yaml` workflow sets
  `TORCH_INSTALL: "1"`, so pkgcheck-action checks pass regardless.

## 4. New reproduction attempt: a real `docker build` (this branch)

The crash context is a `docker build`, not a running container, so the new
repro (`.github/workflows/torch-segfault-docker-repro.yml`) builds four
minimal Dockerfiles (in `./docker/`), each a `docker build --no-cache
--progress=plain` from `eddelbuettel/r2u:24.04`, with full logs uploaded as
artifacts:

| variant | isolates |
|---|---|
| `faithful` | pkgcheck's torch-relevant steps verbatim: bspm block, `ENV ARROW_S3`, r2u binary arrow+torch, `install_arrow()`, then `install_torch()` |
| `no-arrow` | drop arrow entirely -- tests the "arrow immediately before" hypothesis |
| `source-torch` | torch from P3M binaries with bspm disabled -- tests the r2u/bspm system-package hypothesis |
| `gdb` | like faithful, but the *first* install runs under gdb (fresh install, full backtrace on crash) |

All variants fix the three diagnostic flaws of §2.1: marker-file `find
-newer`, `torch_install_path()` + `install_torch_sitrep()` instead of the
wrong cache dir, and exit-code capture + diagnostics inside the same RUN
layer (a later layer would never run after a crash).

Ran 2026-08-02 on the AntoineSoetewey/kindling fork:
[run 30748491813](https://github.com/AntoineSoetewey/kindling/actions/runs/30748491813).
Result: **4/4 negative** (as expected given §2.2):

| variant | result |
|---|---|
| `faithful` | `install_torch exit code: 0`, sitrep healthy, `torch_tensor()` OK. First attempt failed at the *initial apt layer* with a transient `r2u.stat.illinois.edu` connection timeout (nothing to do with torch); rerun passed. |
| `no-arrow` | exit code 0; marker-based file sweep confirms the full libtorch/lantern tree under `torch_install_path()` |
| `source-torch` | exit code 0 (torch from P3M, bspm disabled) |
| `gdb` | fresh install under gdb: `[Inferior 1 (process 13) exited normally]`, `No stack.` |

Build logs (artifacts `torch-docker-repro-*`) archived in
`~/Documents/kindling-torch-segfault-diagnostics/matrix-artifacts/`.

`./server-repro/` contains the piece that can actually catch the crash: a
single never-failing diagnostic `docker build` for @mpadge to run **on the
affected server**, producing exit codes, filesystem state, a gdb backtrace
of a fresh install, sitrep, and environment info in one log.

## 5. Upstream report policy

We do not file at mlverse/torch until we have either a reproduction or a
backtrace from the affected host. A pre-filled issue template (with explicit
placeholders for the backtrace and host info) is in
`./drafts/upstream-issue-mlverse-torch.md`, gated DO-NOT-FILE at the top.
Everything reproducible we have says the install works, and an issue saying
"someone saw a segfault we cannot show" would be noise.

## 6. Remediation for pkgcheck (the part that actually unblocks reviews)

Opened 2026-08-02 as
[ropensci-review-tools/pkgcheck#397](https://github.com/ropensci-review-tools/pkgcheck/pull/397)
(draft kept in `./drafts/pkgcheck-dockerfile-pr.md`): keep `install_torch()` but
make the step crash-tolerant, add a sitrep layer so the build log always
records the resulting state, and set `ENV TORCH_INSTALL "1"` so torch
self-installs at first load if the files really are missing. This makes the
weekly rebuild immune to the segfault whatever its cause, on both pipelines,
while we chase the root cause with the server-side diagnostic build.

## 7. Cleanup plan (the "delete after upstream report" debt)

Preserved before any deletion:

- old workflow artifacts: `./artifacts/` (in-repo) and
  `~/Documents/kindling-torch-segfault-diagnostics/` (outside repo, includes
  the three pkgcheck build logs and the pkgcheck Dockerfile snapshot);
- public log URLs: §2.1 and §2.2 tables.

Steps (second commit on this branch removes the old workflow; the rest
happens once the thread is resolved):

1. ~~Remove `.github/workflows/torch-segfault-repro.yml`~~ (done on this
   branch, superseded by the docker-build workflow).
2. ~~After the next kindling bot check on #784 passes (i.e. the server runs
   an image containing #398): remove
   `.github/workflows/torch-segfault-docker-repro.yml`~~ (done 2026-08-03,
   after the green check linked above; run logs remain public at
   [30748491813](https://github.com/AntoineSoetewey/kindling/actions/runs/30748491813)
   and archived locally).
3. Keep `dev/torch-segfault/` (notes + artifacts) as the process record for
   the rOpenSci skill/blog-post follow-up; or move it out of the repo once
   the blog post exists. `dev/` is in `.Rbuildignore` either way.
4. If upstream turns out to be actionable (backtrace obtained), file the
   issue from the template, then link it from #784 and here.

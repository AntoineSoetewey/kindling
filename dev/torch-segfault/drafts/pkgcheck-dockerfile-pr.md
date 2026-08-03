# DRAFT -- follow-up PR to ropensci-review-tools/pkgcheck

Status: OPENED 2026-08-02 as
https://github.com/ropensci-review-tools/pkgcheck/pull/397 (branch
`torch-install-robust` on the AntoineSoetewey/pkgcheck fork).

## Proposed Dockerfile change

Replace line 320-321:

```diff
 # Other general-purpose installation commands:
-RUN Rscript -e 'torch::install_torch()'
+# torch::install_torch() has segfaulted at process exit on the rOpenSci
+# build server even when the installation itself completed
+# (ropensci/software-review#784). Tolerate an exit-time crash so a completed
+# installation is not discarded with the layer; the sitrep layer records the
+# resulting state in the build log; and TORCH_INSTALL=1 lets torch install
+# itself at first load in case the files really are missing.
+ENV TORCH_INSTALL "1"
+RUN Rscript -e 'torch::install_torch()' \
+    || echo "WARNING: install_torch() exited non-zero; relying on TORCH_INSTALL=1 fallback"
+RUN Rscript -e 'torch::install_torch_sitrep()' \
+    || echo "WARNING: install_torch_sitrep() exited non-zero"
```

(`ENV key value` legacy form kept for consistency with the rest of the file,
e.g. `ENV ARROW_S3 "ON"`.)

## PR title

Make torch installation robust to install_torch() exit-time segfault

## PR body

---

Follow-up to #393 and to the segfault @mpadge reported in
ropensci/software-review#784: on the rOpenSci build server,
`RUN Rscript -e 'torch::install_torch()'` dies with a segfault, apparently
*after* the installation itself completes ("failed somewhere in the cleanup
process"). When that happens during `docker build`, the RUN step returns 139
and the layer -- including the completed installation -- is discarded, so
the weekly server rebuild loses torch entirely.

Notably, this repo's own `docker.yaml` CI has built the identical Dockerfile
successfully three times since #393 (runs
[29487664312](https://github.com/ropensci-review-tools/pkgcheck/actions/runs/29487664312),
[29712935423](https://github.com/ropensci-review-tools/pkgcheck/actions/runs/29712935423),
[30232503908](https://github.com/ropensci-review-tools/pkgcheck/actions/runs/30232503908)),
with `install_torch()` executing in ~10 s and exiting 0. The crash appears
specific to the server environment; we're pursuing the root cause separately
(diagnostic build for the affected host + upstream report to mlverse/torch
once a backtrace exists).

This PR makes the image build robust to it regardless of cause:

1. **`|| echo ...` on the install step** -- an exit-time segfault no longer
   fails the build, so an installation that completed before the crash is
   kept in the layer instead of thrown away. On hosts where the step is
   healthy (like CI here) nothing changes.
2. **A `torch::install_torch_sitrep()` layer** -- the build log always
   records whether libtorch/lantern actually landed, so a broken torch state
   is visible instead of silent.
3. **`ENV TORCH_INSTALL "1"`** -- the mechanism @mpadge already used as a
   manual patch, now permanent as a last-resort fallback: if the files
   really are missing at check time, torch installs itself on first load
   rather than hard-failing the checked package.

Alternative considered: dropping the RUN step and relying on
`TORCH_INSTALL=1` alone (the manual patch). That works, but moves the
170 MB libtorch download from image-build time to first use inside review
containers; keeping the baked install as the primary path avoids that, with
the envvar as safety net.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

---

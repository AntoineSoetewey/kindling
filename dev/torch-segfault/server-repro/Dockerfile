# Self-contained diagnostic build for the torch::install_torch() segfault
# observed on the rOpenSci build server (ropensci/software-review#784).
#
# Unlike the bisection variants in ../docker/, this build NEVER fails: every
# step is tolerant, so a single `docker build` produces a complete diagnostic
# log even when install_torch() crashes. Intended to be run on the host where
# the segfault occurs:
#
#   docker build --progress=plain --no-cache -t torch-segfault-diag . \
#       2>&1 | tee torch-segfault-diag.log
#
# and the resulting torch-segfault-diag.log shared, together with host info:
#
#   { docker version; uname -a; lscpu; } > host-info.txt 2>&1

FROM eddelbuettel/r2u:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
                sudo \
                r-cran-bspm \
                gdb \
        && echo "bspm::enable()" >> /etc/R/Rprofile.site \
        && echo "options(bspm.sudo=TRUE)" >> /etc/R/Rprofile.site \
        && echo 'APT::Install-Recommends "false";' > /etc/apt/apt.conf.d/90local-no-recommends \
        && echo "docker ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/local-docker-user \
        && chmod 0440 /etc/sudoers.d/local-docker-user \
        && chgrp 1000 /usr/local/lib/R/site-library \
        && install.r remotes

ENV ARROW_S3 "ON"

# Same torch/arrow provenance as the pkgcheck image (r2u/bspm apt binaries)
RUN install2.r arrow torch

RUN Rscript -e 'arrow::install_arrow()' || echo "NOTE: install_arrow exited non-zero: $?"

RUN touch /tmp/torch-install-marker && sleep 1

# Step 1: plain install_torch(), exactly as in the pkgcheck Dockerfile, but
# tolerant, with the exit code and filesystem state recorded in this layer.
RUN Rscript -e 'torch::install_torch()'; ec=$?; \
    echo "=== [1] plain install_torch exit code: $ec ==="; \
    echo "=== [1] torch::torch_install_path() contents ==="; \
    Rscript -e 'p <- torch::torch_install_path(); cat(p, "\n"); print(list.files(p, recursive = TRUE))' || true; \
    echo "=== [1] files created since marker ==="; \
    find / -xdev -newer /tmp/torch-install-marker \( -iname "*torch*" -o -iname "*lantern*" \) -type f 2>/dev/null | grep -v '^/proc' || true; \
    true

# Step 2: a second, guaranteed-fresh install under gdb, into a separate
# TORCH_HOME so install_torch() cannot short-circuit on the step-1 files.
# If the crash reproduces, "bt full" below is the backtrace we need upstream.
RUN mkdir -p /opt/torch-gdb-home; \
    TORCH_HOME=/opt/torch-gdb-home \
    gdb -q -batch -ex run -ex "bt full" -ex "thread apply all bt" \
        --args Rscript -e 'torch::install_torch()' \
        2>&1 | sed 's/^/[gdb] /'; \
    true

# Step 3: state report and environment details, in fresh processes.
RUN echo "=== [3] sitrep ==="; \
    Rscript -e 'torch::install_torch_sitrep()' || echo "NOTE: sitrep exited non-zero: $?"; \
    echo "=== [3] load test ==="; \
    Rscript -e 'print(torch::torch_tensor(1:3))' || echo "NOTE: load test exited non-zero: $?"; \
    echo "=== [3] environment ==="; \
    uname -a; ldd --version | head -1; \
    Rscript -e 'print(sessionInfo()); print(packageVersion("torch"))'; \
    grep -m1 flags /proc/cpuinfo | tr ' ' '\n' | grep -E 'avx|sse4' | paste -sd' ' -; \
    true

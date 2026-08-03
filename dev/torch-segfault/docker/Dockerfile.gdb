# Variant "gdb": same setup as Dockerfile.faithful, but the FIRST (and only)
# install_torch() run happens under gdb, so if it segfaults we get a full
# backtrace from a genuinely fresh installation.
# The old repro workflow ran gdb only as a SECOND invocation, after a
# successful install; install_torch(reinstall = FALSE) then skips the
# download/unpack phase, so the gdb run exercised mostly the load-verification
# path rather than a clean install.
# The layer fails unless gdb reports the inferior "exited normally", so a
# crash fails the docker build just like the real step would.

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

RUN install2.r arrow torch

RUN Rscript -e 'arrow::install_arrow()'

RUN ulimit -c unlimited; \
    gdb -q -batch -ex run -ex "bt full" -ex "thread apply all bt" \
        --args Rscript -e 'torch::install_torch()' \
        > /tmp/gdb-backtrace.txt 2>&1; \
    cat /tmp/gdb-backtrace.txt; \
    grep -q "exited normally" /tmp/gdb-backtrace.txt

RUN Rscript -e 'torch::install_torch_sitrep()'
RUN Rscript -e 'print(torch::torch_tensor(1:3))'

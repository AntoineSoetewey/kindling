# One-command diagnostic build for the `install_torch()` segfault

For whoever has access to the host where `torch::install_torch()` segfaults
during `docker build` (the rOpenSci build server -- see
ropensci/software-review#784). All public builds of the same recipe pass, so
this needs to run on the affected host.

From this directory:

```sh
docker build --progress=plain --no-cache -t torch-segfault-diag . \
    2>&1 | tee torch-segfault-diag.log
{ docker version; uname -a; lscpu; } > host-info.txt 2>&1
```

The build is designed to **never fail**: every step is tolerant, so you get a
complete `torch-segfault-diag.log` in one pass even when the crash occurs. It
runs `install_torch()` twice -- once plainly (exit code + filesystem state
recorded), once fresh under `gdb` (full backtrace if it crashes) -- and ends
with `torch::install_torch_sitrep()` plus environment details.

Please share `torch-segfault-diag.log` and `host-info.txt`.

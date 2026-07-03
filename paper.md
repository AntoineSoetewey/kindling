---
title: 'kindling: A Higher-Level torch Interface for Generating, Training, and Tuning Neural Networks in R'
tags:
  - R
  - deep learning
  - neural networks
  - torch
  - tidymodels
  - code generation
authors:
  - name: Antoine Soetewey
    orcid: 0000-0001-8159-0804
    affiliation: 1
  - name: Joshua Marie
    affiliation: 2
affiliations:
  - name: HEC Liège, Université de Liège, Rue Louvrex 14, 4000 Liège, Belgium
    index: 1
  - name: Independent Researcher
    index: 2
date: 03 July 2026
bibliography: paper.bib
---

# Summary

`kindling` is an R [@rcoreteam2025] package that provides a higher-level interface to the `torch` package [@falbelluraschi2025torch], R's native implementation of PyTorch, for defining, training, and tuning neural networks. It supports feedforward architectures (multi-layer perceptrons) and recurrent variants (RNN, LSTM, GRU), and reduces the boilerplate typically required to write `torch` training loops by hand.

The package is organized around three levels of abstraction. At the lowest level, `_generator` functions (for example `ffnn_generator()`) return unevaluated `torch::nn_module()` expressions that users can inspect or modify directly, since `kindling` builds its models through code generation rather than opaque wrapper objects. At an intermediate level, functions such as `ffnn()` and `rnn()` train a model directly from a formula and data frame, handling data preparation, the optimization loop, and, optionally, early stopping and a validation split. At the highest level, `mlp_kindling()` and `rnn_kindling()` register these models as `parsnip` model specifications [@kuhnvaughan2026parsnip], so they can be fit, tuned, and evaluated using the rest of the `tidymodels` ecosystem [@kuhnwickham2020tidymodels]: `recipes` for preprocessing, `workflows` for bundling preprocessing and modeling steps, and `tune`/`dials` for hyperparameter search over layer widths, network depth, activation functions, the output activation, the optimizer, and other architectural choices. Fitted models can also be inspected with variable-importance methods from `NeuralNetTools` [@beck2018neuralnettools], implementing the algorithms of Garson [@garson1991] and Olden and Jackson [@oldenjackson2002], and with the `vip` package.

# Statement of need

`torch` gives R users direct access to tensors, automatic differentiation, and GPU acceleration, but writing a `torch::nn_module()`, a training loop, and the surrounding data-handling code by hand is repetitive and error-prone, particularly for users who want to compare several architectures or run a hyperparameter search rather than fit one fixed model. At the same time, R's dominant applied machine learning framework, `tidymodels`, historically has had comparatively narrow neural network support, and most existing higher-level `torch` wrappers do not expose the generated model code or integrate with the tuning and resampling infrastructure that `tidymodels` users already rely on for other model types.

`kindling` addresses this gap for R users who want deep learning to sit inside a `tidymodels` workflow rather than beside it. Because model specifications built with `mlp_kindling()` or `rnn_kindling()` behave like any other `parsnip` model, an analyst who already tunes a random forest or a boosted tree with `tune::tune_grid()` and `rsample` resamples can point the same workflow at a neural network with only the model specification changed. The code generation layer additionally lets users audit or extend the underlying `torch` module instead of treating it as a black box, which is useful both for teaching and for architectures that need small custom modifications.

# State of the field

Several R packages sit above `torch` to reduce this boilerplate, and each targets a different point on the tradeoff between flexibility and convenience. `brulee` [@kuhnfalbel2025brulee] is the official `tidymodels` package for `torch`-based models; it offers production-oriented, batteries-included implementations of linear, logistic, and multinomial regression and a multi-layer perceptron, but does not expose code generation or recurrent architectures. `cito` [@amesoder2024cito] emphasizes statistical inference and explainability for fully-connected networks and convolutional networks through a formula interface, with an extensive set of interpretation tools (partial dependence, accumulated local effects, bootstrap confidence intervals), but it is a standalone package rather than a `tidymodels` engine. `luz` provides a general, high-level training-loop abstraction for arbitrary `torch::nn_module()` objects [@falbel2025luz]; it is architecture-agnostic and reduces boilerplate at the loop level, but does not offer a formula interface, code generation, or `tidymodels` integration.

`kindling` is positioned alongside, not in place of, these packages: it combines inspectable code generation, both feedforward and recurrent architecture families, and full `tidymodels` integration (`parsnip` specifications, `tune`/`dials` search spaces, and `recipes`/`workflows` pipelines) in one package. `mlr3` [@lang2019mlr3] is the other major R modeling framework and is a planned integration target for `kindling`, alongside its current `tidymodels` support. In practice, the choice between these packages depends on the task: `brulee` for production-ready standard architectures, `cito` for statistical inference and explainability, `luz` for custom training loops, and `kindling` for `tidymodels`-native workflows that need architectural flexibility or inspectable generated code.

# Software design

`kindling`'s central design decision is to separate code generation from execution. The `_generator` functions build quoted `torch::nn_module()` expressions through R's metaprogramming facilities rather than instantiating an opaque model object internally; the same expression can be printed, copied, hand-edited, and run outside `kindling`. This costs an extra layer (an expression-building step that a direct wrapper would not need), but it means a user, reviewer, or student can verify exactly what network is being fit rather than trust a black box, and can extend a generated architecture for a case the higher-level wrappers do not cover.

The three-level API (code generation, direct training, `tidymodels` engine) follows from that same trade-off, applied at increasing levels of convenience and constraint. `train_nn()` and its wrappers (`ffnn()`, `rnn()`) dispatch on the class of their input (`matrix`, `data.frame`, `formula`, or `torch` `dataset`), and preprocessing is delegated to `hardhat::mold()`/`forge()` rather than reimplemented, so `kindling` models inherit the same predictor-role, factor-encoding, and missing-data handling as other `parsnip`/`recipes` engines. Tunable parameters (`hidden_neurons()`, `activations()`, `output_activation()`, `grid_depth()`) are implemented as `dials` parameter objects dispatched over `default`/`list`/`model_spec`/`param` classes, so they plug directly into `tune::tune_grid()`'s search-space machinery instead of a bespoke tuning loop. This constrains `kindling` to `tidymodels` conventions, but it is precisely what lets a `tidymodels` user reuse existing resampling and tuning code for a neural network instead of learning a separate API.

Within the generated code itself, activation functions are specified through `act_funs()`, a small embedded DSL built on `rlang` non-standard evaluation that accepts bracket syntax such as `softshrink[lambd = 0.5]` for parametric activations, and `new_act_fn()` as an escape hatch for activations with no `torch::nnf_*()` equivalent. This trades some NSE complexity in the implementation for a call-like syntax at the user level, avoiding nested lists of function names and parameter values.

# Research impact statement

`kindling` is a young package (the GitHub repository was created in November 2025) and does not yet have external citations, publications, or third-party integrations to report; the evidence below documents community-readiness rather than realized adoption. It is available on CRAN (initial release 0.1.0; current release 0.3.1), with 1,434 downloads recorded since January 2025 and 278 downloads in the last month, and the GitHub repository has 27 stars and 5 forks. Correctness is backed by a test suite of 206 `testthat` test blocks covering the code generators, the direct-training wrappers, the `tidymodels` engines, and the tuning/`dials` integration, run continuously via GitHub Actions `R-CMD-check` and tracked with Codecov. Development has been active and responsive: 20 pull requests have been merged since the repository's creation, and reported issues have been triaged and fixed within the same development cycle (for example, issue #21, a functional bug in `output_activation = "linear"`, was fixed and covered by a permanent regression test the same day it was reported).

# AI usage disclosure

Generative AI was used in two distinct, disclosed ways. First, within the `kindling` codebase itself, GitHub Copilot is recorded as a co-author on 5 of the repository's 403 commits (touching a CI workflow file, `NEWS.md` twice, one test file, and `README.Rmd`), visible via `Co-authored-by` trailers in the Git history; this is the complete extent of generative-AI involvement in the package's code and documentation, confirmed by the authors. Second, this paper and its bibliography were drafted with the assistance of Claude (Anthropic's Claude Code), reviewed and edited by the human authors before submission. Claims in the bibliography were checked against either the installed packages' own `citation()` output or the Crossref API rather than accepted as generated; the figure was produced by executing `kindling`'s own `ffnn()` and `garson()` functions on the example already used in the package's README, not hand-drawn; and the compiled paper was verified to build cleanly with `pandoc --citeproc`, with all citation keys cross-checked between `paper.md` and `paper.bib`.

# Figure

![Garson's algorithm variable-importance scores [@garson1991], computed with `kindling`'s `garson()` wrapper around `NeuralNetTools` [@beck2018neuralnettools] for a feedforward network trained on the `iris` dataset (the same model used in the package's README "Direct Training Interface" example). Generated with: `model = ffnn(Species ~ ., data = iris, hidden_neurons = c(10, 15, 7), activations = act_funs(relu, softshrink[lambd = 0.5], elu), loss = "cross_entropy", epochs = 100); garson(model, bar_plot = TRUE)`.](paper-figure.png)

# Acknowledgements

We thank the maintainers of `torch` for R and of the `tidymodels` ecosystem, on which `kindling` is built.

# References

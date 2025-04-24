# NGAFFTB - Next Generation Arithmetic FFT Benchmarks

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.15205716.svg)](https://doi.org/10.5281/zenodo.15205716)

This repository provides facilities for running automated large-scale
benchmarks on FFTs applied to datasets across multiple machine
number formats, including IEEE 754 floating-point numbers, OFP8, bfloat16,
posit arithmetic, and takum arithmetic.

## Getting started

You can automatically run the benchmarks (and generate the plot file
plots/fft.pdf) via

```sh
make
```

Runtime parameters (thread count, datasets) can be controlled by editing
`config.mk`.

## Authors and License

NGAFFTB is developed by Laslo Hunhold and licensed under the ISC license.
See LICENSE for copyright and license details.

# See LICENSE file for copyright and license details.
using SparseArrays

push!(LOAD_PATH, "src/")
using Crutches
using Experiments
using PDE

write_experiment_results(
	ExperimentResults(
		Experiment(;
			parameters = [PDEExperimentParameters(PoissonPDEParameters(; Nx = Nx, σ = 0.4)) for Nx in 2:100],
			number_types = Experiments.all_number_types,
		),
	),
)

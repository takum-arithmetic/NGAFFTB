# See LICENSE file for copyright and license details.
using SparseArrays

push!(LOAD_PATH, "src/")
using Crutches
using Experiments
using PDE

write_experiment_results(
	ExperimentResults(
		Experiment(;
			parameters = [
				PDEExperimentParameters(
					HeatPDEParameters(;
						Nx = 5000,
						Nt = Nt,
						α = 1e13,
						σ = 0.1,
					),
				) for Nt in 1:500
			],
			number_types = Experiments.all_number_types,
		),
	),
)

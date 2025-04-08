# See LICENSE file for copyright and license details.
using SparseArrays

push!(LOAD_PATH, "src/")
using Crutches
using Experiments
using PDE

write_experiment_results(
	ExperimentResults(
		Experiment(;
			parameters = [ ImageExperimentParameters(; file_name = file_name) for file_name in readlines("src/generate_image_dataset.output") ],
			number_types = Experiments.all_number_types,
		),
	),
)

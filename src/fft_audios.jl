# See LICENSE file for copyright and license details.
using SparseArrays

push!(LOAD_PATH, "src/")
using Crutches
using Experiments
using PDE

write_experiment_results(
	ExperimentResults(
		Experiment(;
			parameters = [ AudioExperimentParameters(; file_name = file_name, window_size = 2048, hop_size = 1024, zero_padding_factor = 2) for file_name in readlines("src/generate_audio_dataset.output") ],
			number_types = Experiments.all_number_types,
		),
	),
)

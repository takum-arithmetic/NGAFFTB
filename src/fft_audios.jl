# See LICENSE file for copyright and license details.
using SparseArrays

push!(LOAD_PATH, "src/")
using Crutches
using Experiments
using PDE

parameters = [
	AudioExperimentParameters(;
		file_name = file_name,
		window_size = 2048,
		hop_size = 1024,
		zero_padding_factor = 2,
	) for file_name in readlines("src/generate_audio_dataset.output")
]

# honour the request for reduced test data
if "--reduced-test-data" in ARGS
	parameters = parameters[1:min(50, end)]
end

write_experiment_results(
	ExperimentResults(
		Experiment(;
			parameters = parameters,
			number_types = Experiments.all_number_types,
		),
	),
)

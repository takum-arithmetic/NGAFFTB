# See LICENSE file for copyright and license details.
module Experiments

push!(LOAD_PATH, "src/")
using Base.Threads
using BFloat16s
using CSV
using DataFrames
using Float128Conversions
using LinearAlgebra
using PDE
using Posits
using Printf
using Quadmath
using Takums
using MicroFloatingPoints

export AbstractExperimentParameters,
	AbstractExperimentPreparation,
	AbstractExperimentMeasurement,
	Experiment,
	ExperimentResults,
	write_experiment_results,
	PDEExperimentParameters,
	PDEExperimentPreparation,
	PDEExperimentMeasurement,
	ImageExperimentParameters,
	ImageExperimentPreparation,
	ImageExperimentMeasurement,
	AudioExperimentParameters,
	AudioExperimentPreparation,
	AudioExperimentMeasurement

all_number_types = [
	Floatmu{4, 3},
	Floatmu{5, 2},
	#Takum8,
	LinearTakum8,
	Posit8,
	#Takum16,
	LinearTakum16,
	Posit16,
	BFloat16,
	Float16,
	#Takum32,
	LinearTakum32,
	Posit32,
	Float32,
	#Takum64,
	LinearTakum64,
	Posit64,
	Float64,
]

abstract type AbstractExperimentParameters end
abstract type AbstractExperimentPreparation end
abstract type AbstractExperimentMeasurement end

@kwdef struct Experiment
	parameters::Vector{AbstractExperimentParameters}
	number_types::Vector{DataType}
end

@enum MeasurementError MatrixSingular MatrixUnderOverflow

struct ExperimentResults
	experiment::Experiment
	measurement::Matrix{Union{AbstractExperimentMeasurement, MeasurementError, Missing}}
end

@enum _MeasurementState pending = 0 processing done

let
	# export the function name globally
	global _print_progress

	# we are within the let..end scope, this simulates a static variable
	last_output_length = 0

	function _print_progress(progress::Matrix{_MeasurementState}, experiment::Experiment)
		# make a local copy
		progress = copy(progress)

		# determine the number of completed and total measurements
		num_done = length(progress[progress .== done])
		num_total = length(progress)

		# generate a matrix of measurement identifiers ("parameter_string[type_name]")
		identifiers = [
			String(p) * "[" * String(nameof(t)) * "]" for t in experiment.number_types,
			p in experiment.parameters
		]

		# get a list of identifiers that are currently active
		currently_processing_identifiers =
			identifiers[progress .== processing]

		# generate output string
		output = @sprintf "(%03i/%03i)" num_done num_total
		if length(currently_processing_identifiers) > 0
			output *= " currently processing:"
			for id in currently_processing_identifiers
				output *= " " * id
			end
		end

		# move back carriage return, write sufficiently many spaces to
		# cover the previous output, then another carriage return,
		# then the output string
		print(stderr, "\r" * (" "^last_output_length) * "\r" * output)

		# set the last output length for the next iteration
		return last_output_length = length(output)
	end
end

function ExperimentResults(experiment::Experiment)
	# this is where we store the measurements
	measurement = Matrix{Union{AbstractExperimentMeasurement, MeasurementError, Missing}}(
		missing,
		length(experiment.number_types),
		length(experiment.parameters),
	)

	# this is a matrix in which the threads mark their progress
	progress = _MeasurementState.(zeros(Integer, size(measurement)))
	print_lock = ReentrantLock()

	# do all the desired measurements
	@threads for i in 1:length(experiment.parameters)
		parameters = experiment.parameters[i]

		# run the preparation function that computes any general
		# things that do not change with each number type
		local preparation
		#		try
		preparation = get_preparation(parameters)
		#		catch e
		# Something went wrong in the preparation, making
		# it an unsuitable example. We just set all
		# the types to a measurement error and to done
		#			measurement[1:length(experiment.number_types), i] .=
		#				MatrixSingular::MeasurementError
		#			progress[1:length(experiment.number_types), i] .=
		#				done
		#
		#			continue
		#		end

		@threads for j in 1:length(experiment.number_types)
			# set the current problem to active
			progress[j, i] = processing

			# print the current status when the lock is not
			# held, otherwise just keep going
			if trylock(print_lock)
				_print_progress(progress, experiment)
				unlock(print_lock)
			end

			# call the main get_measurement function identified
			# by the type of parameters, passing in the
			# prepared data
			measurement[j, i] = get_measurement(
				experiment.number_types[j],
				parameters,
				preparation,
			)

			# set the current problem to done
			progress[j, i] = done
			if trylock(print_lock)
				_print_progress(progress, experiment)
				unlock(print_lock)
			end
		end
	end

	# print a new line
	print(stderr, "\n")

	return ExperimentResults(experiment, measurement)
end

function write_experiment_results(experiment_results::ExperimentResults)
	# the measurement matrix contains a mix of MeasurementErrors, missing and the used
	# subtype of AbstractExperimentMeasurement. The first thing we do
	# is filter out the MeasurementErrors and missings and then check if it's homogeneously
	# one type.
	local measurement_type
	local measurement_type_instance

	valid_measurements = experiment_results.measurement[typeof.(
		experiment_results.measurement,
	) .<: AbstractExperimentMeasurement]

	if length(valid_measurements) == 0
		# we only have invalid measurements
		throw(ArgumentError("All measurements are invalid"))
	else
		# check if all valid measurements are of one type
		measurement_types = union(typeof.(valid_measurements))

		if length(measurement_types) != 1
			throw(
				ArgumentError(
					"Measurement types are not homogeneous",
				),
			)
		else
			measurement_type = measurement_types[1]
			measurement_type_instance = valid_measurements[1]
		end
	end

	for field_name in fieldnames(measurement_type)
		# get underlying experiment
		experiment = experiment_results.experiment

		# generate array of strings
		type_names = String.(nameof.(experiment.number_types))
		matrix_names = String.(experiment.parameters)

		# generate CSV
		df = DataFrame(
			Matrix{
				typeof(
					getfield(
						measurement_type_instance,
						field_name,
					),
				),
			}(
				undef,
				length(experiment.parameters),
				length(type_names) + 1,
			),
			:auto,
		)

		# assign the first column to be the matrix names
		df[!, 1] = matrix_names

		# fill the DataFrame with values from R
		for i in 1:length(type_names)
			df[!, i + 1] = [
				if typeof(m) == MeasurementError
					if (
						m ==
						MatrixSingular::MeasurementError
					)
						-Inf
					elseif (
						m ==
						MatrixUnderOverflow::MeasurementError
					)
						Inf
					else
						throw(
							DomainError(
								m,
								"Unhandled enum type",
							),
						)
					end
				elseif isnan(
					getfield(
						m,
						field_name,
					),
				)
					# if a NaN happened otherwise it is due to
					# a singularity, we book it as an Inf
					Inf
				elseif typeof(m) == Missing
					throw(
						ErrorException(
							"There are missing measurements",
						),
					)
				else
					getfield(m, field_name)
				end for m in
				experiment_results.measurement[i, :]
			]
		end

		# Set the row names as the parameter names
		rename!(df, [Symbol("parameter\\type"); Symbol.(type_names)])

		experiment_name = chopsuffix(basename(PROGRAM_FILE), ".jl")

		# create output directory
		directory_name = "out/" * experiment_name
		if !(isdir(directory_name))
			mkdir(directory_name)
		end

		# generate file name
		file_name = directory_name * "/" * String(field_name) * ".csv"

		# write the DataFrame to the target file
		CSV.write(file_name, df)

		# print the written file name to standard output for the witness file
		println(file_name)
	end
end

@kwdef struct PDEExperimentParameters <: AbstractExperimentParameters
	pde_parameters::AbstractPDEParameters
end

function Base.String(p::PDEExperimentParameters)
	return "PDE"
end

@kwdef struct PDEExperimentPreparation <: AbstractExperimentPreparation
	solution_exact::VecOrMat{Float128}
end

function get_preparation(parameters::PDEExperimentParameters)
	solution_exact = solve(parameters.pde_parameters, Float128)

	return PDEExperimentPreparation(solution_exact)
end

@kwdef struct PDEExperimentMeasurement <: AbstractExperimentMeasurement
	absolute_error::Float128
	relative_error::Float128
end

function get_measurement(
	::Type{T},
	parameters::PDEExperimentParameters,
	preparation::PDEExperimentPreparation,
) where {T <: AbstractFloat}
	local solution_approx

	try
		solution_approx = Float128.(solve(parameters.pde_parameters, T))
	catch e
		if isa(e, DomainError)
			# No problemo, we have provisioned for this
			return MatrixUnderOverflow::MeasurementError
		else
			rethrow(e)
		end
	end

	absolute_error = norm(preparation.solution_exact - solution_approx)
	relative_error = absolute_error / norm(preparation.solution_exact)

	return PDEExperimentMeasurement(absolute_error, relative_error)
end

using GenericFFT
using Images

@kwdef struct ImageExperimentParameters <: AbstractExperimentParameters
	file_name::String
end

function Base.String(p::ImageExperimentParameters)
	return p.file_name
end

@kwdef struct ImageExperimentPreparation <: AbstractExperimentPreparation
	image::Matrix{RGB{Float128}}
end

function get_preparation(parameters::ImageExperimentParameters)
	# Load the image file
	return ImageExperimentPreparation(;
		image = RGB{Float128}.(load(parameters.file_name)),
	)
end

@kwdef struct ImageExperimentMeasurement <: AbstractExperimentMeasurement
	absolute_error::Float128
	relative_error::Float128
end

function get_measurement(
	::Type{T},
	parameters::ImageExperimentParameters,
	preparation::ImageExperimentPreparation,
) where {T <: AbstractFloat}
	local image_roundtrip

	try
		# Look at each colour channel and do a 2D FFT in the target
		# type. There is no need for a shift as this is just a
		# rearrangement. Then directly apply the inverse FFT.
		R = ifft(fft(T.(red.(preparation.image))))
		G = ifft(fft(T.(green.(preparation.image))))
		B = ifft(fft(T.(blue.(preparation.image))))

		# Combine the three channels again into an RGB matrix of type T
		image_roundtrip = RGB.(R, G, B)
	catch e
		if isa(e, DomainError)
			# No problemo, we have provisioned for this
			return MatrixUnderOverflow::MeasurementError
		else
			rethrow(e)
		end
	end

	# Compute absolute and relative errors
	absolute_error = norm(preparation.image - RGB{Float128}.(image_roundtrip))
	relative_error = absolute_error / norm(preparation.image)

	return ImageExperimentMeasurement(absolute_error, relative_error)
end

using WAV

@kwdef struct AudioExperimentParameters <: AbstractExperimentParameters
	file_name::String
	window_size::Int
	hop_size::Int
	zero_padding_factor::Int
end

function Base.String(p::AudioExperimentParameters)
	return p.file_name
end

@kwdef struct AudioExperimentPreparation <: AbstractExperimentPreparation
	samples::Vector{Float64}
	stft_exact::Matrix{Complex{Float128}}
end

function run_stft(
	::Type{T},
	samples::Vector{Float64},
	window_size::Int,
	hop_size::Int,
	zero_padding_factor::Int,
) where {T <: AbstractFloat}
	# determine the STFT segment count, as we have established it
	# as a multiple of the hop size. This is why we blindly convert
	# to Int, as any deviation would yield an inexact error, ensuring
	# a proper preparation. We have a +1 because if the window size
	# is exactly the length of the samples, the division will yield
	# zero, but we have one STFT segment after all.
	segment_count = Int((length(samples) - window_size) / hop_size) + 1

	# we prepare the filter applied to our segments, making
	# use of the Hann function k -> sin²(π(k-1)/(window_size-1)) with
	# segment indices i in {1,...,window_size}
	filter = sinpi.(T.(collect(0:(window_size - 1))) ./ T(window_size - 1)) .^ 2

	# with zero padding you add a multiple of the window size as zeros
	# at the end of each segment
	padded_window_size = zero_padding_factor * window_size

	# allocate a padded_window_size x segment_count zero matrix for the
	# results. The columns contain the frequency contributions, and
	# each column corresponds with one segment in temporal order.
	result = zeros(Complex{T}, padded_window_size, segment_count)

	# iterate over the segments
	for s in 1:segment_count
		# extract the segment
		start_index = 1 + (s - 1) * hop_size
		segment = T.(samples[start_index:(start_index + window_size - 1)])

		# apply the Hann function filter
		segment = filter .* segment

		# apply zero-padding at the end
		segment = vcat(segment, zeros(T, padded_window_size - window_size))

		# fft
		local segment_fft
		try
			segment_fft = fft(segment)
		catch e
			if isa(e, DomainError)
				# No problemo, we have provisioned for this
				return nothing
			else
				rethrow(e)
			end
		end

		# enter the result into the result matrix
		result[:, s] = segment_fft
	end

	return result
end

function get_preparation(parameters::AudioExperimentParameters)
	# Load the sound file
	samples, = wavread(parameters.file_name)

	# Convert samples from a matrix to a vector
	samples = samples[:]

	# we need at least as many samples as our window size
	if length(samples) < parameters.window_size
		samples = vcat(
			samples,
			zeros(parameters.window_size - length(samples)),
		)
	end

	let
		# the hop size determines our sample count, as the sample count
		# minus the window size must be a multiple of it. We enforce it
		# here by dividing the hop area size by the hop size, rounding
		# that up and adding that many zeros to the samples
		hop_area_size = length(samples) - parameters.window_size

		if hop_area_size % parameters.hop_size != 0
			samples = vcat(
				samples,
				zeros(
					Int(
						ceil(
							hop_area_size /
							parameters.hop_size,
						),
					) *
					parameters.hop_size -
					hop_area_size,
				),
			)
		end
	end

	# determine the reference solution
	stft_exact = run_stft(
		Float128,
		samples,
		parameters.window_size,
		parameters.hop_size,
		parameters.zero_padding_factor,
	)

	return AudioExperimentPreparation(; samples = samples, stft_exact = stft_exact)
end

@kwdef struct AudioExperimentMeasurement <: AbstractExperimentMeasurement
	absolute_error::Float128
	relative_error::Float128
end

function get_measurement(
	::Type{T},
	parameters::AudioExperimentParameters,
	preparation::AudioExperimentPreparation,
) where {T <: AbstractFloat}
	stft_approx = run_stft(
		T,
		preparation.samples,
		parameters.window_size,
		parameters.hop_size,
		parameters.zero_padding_factor,
	)

	# Catch a possible error case
	if stft_approx == nothing
		return MatrixUnderOverflow::MeasurementError
	end

	# Compute absolute and relative errors
	absolute_error = norm(preparation.stft_exact - Complex{Float128}.(stft_approx))
	relative_error = absolute_error / norm(preparation.stft_exact)

	return AudioExperimentMeasurement(absolute_error, relative_error)
end

end

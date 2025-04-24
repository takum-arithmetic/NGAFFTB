# See LICENSE file for copyright and license details.
module PDE

push!(LOAD_PATH, "src/")
using Crutches
using GenericFFT
using LinearAlgebra

export AbstractPDEParameters, AbstractPDEResult, HeatPDEParameters, PoissonPDEParameters, solve

abstract type AbstractPDEParameters end
abstract type AbstractPDEResult end

# We always look at spatial domain [0,1] and temporal domain [0,1]
@kwdef struct HeatPDEParameters <: AbstractPDEParameters
	Nx::Int
	Nt::Int
	α::AbstractFloat
	σ::AbstractFloat
end

function solve(parameters::HeatPDEParameters, ::Type{T}) where {T <: AbstractFloat}
	# time and space domains (omitting last space point for periodicity)
	dt = one(T) / parameters.Nt
	dx = one(T) / parameters.Nx
	x = LinRange(zero(T), one(T), parameters.Nx + 1)[1:(end - 1)]

	# use a Gaussian pulse centered at 0.5 with initial width sigma0
	# as an initial condition
	u0 = exp.(-((x .- T(0.5)) .^ 2) / (T(2) * parameters.σ^2))
	#u0 = (xs -> ((xs >= 0.4 && xs <= 0.6) ? one(T) : zero(T))).(x)

	# compute the DFT sample frequencies
	k = fftfreq(parameters.Nx, dx) * T(2.0) * T(π)

	# obtain the Fourier transform of the initial condition
	uhat = fft(u0)

	# precompute the exponential integrating factor
	E = exp.(-T(parameters.α) * k .^ 2 * dt)

	# iterate over time, applying the integrating factor in Fourier
	# space in each time step
	for _ in 1:parameters.Nt
		uhat .*= E
	end

	# transform back
	u1 = real(ifft(uhat))

	return u1
end

# We always look at spatial domain [0,1]
# analytical solution exp(-(x²+y²)/(2*σ²))
@kwdef struct PoissonPDEParameters <: AbstractPDEParameters
	Nx::Int # 1-1000
	σ::AbstractFloat # 0.1
end

# https://atmos.washington.edu/~breth/classes/AM585/lect/FS_2DPoisson.pdf
function solve(parameters::PoissonPDEParameters, ::Type{T}) where {T <: AbstractFloat}
	# space domains (omitting last space point for periodicity)
	dx = one(T) / parameters.Nx
	x = LinRange(zero(T), one(T), parameters.Nx + 1)[1:(end - 1)]

	# compute the DFT sample frequencies
	k = T(2) * T(pi) * fftfreq(parameters.Nx)

	# Laplacian in frequency domain, avoiding division by zero at
	# zero frequencies
	L = [-(kx^2 + ky^2) for kx in k, ky in k]
	L[1, 1] = one(T)

	# generate initial conditions
	rsq(x, y) = (x - 0.5)^2 + (y - 0.5)^2
	f(x, y) =
		exp(-rsq(x, y)/(2*parameters.σ^2)) *
		(rsq(x, y) - 2*parameters.σ^2)/(parameters.σ^4)
	F = [f(xi, yi) for xi in x, yi in x]

	# perform FFT
	F_hat = fft(F)

	# solve in the frequency domain
	u_hat = F_hat ./ L

	# perform inverse FFT to obtain spatial solution
	u = real(ifft(u_hat))

	# ensure uniqueness by forcing corner (0,0) to be zero
	u = u .- u[1, 1]

	return u
end

end

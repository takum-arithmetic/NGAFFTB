# See LICENSE file for copyright and license details.
module Crutches

push!(LOAD_PATH, "src/")
using BFloat16s
using Float128Conversions
using MicroFloatingPoints
using Posits
using Quadmath
using Takums

# rem for Posits and Takums
Base.rem(x::LinearTakum8, y::LinearTakum8) = LinearTakum8(rem(Float64(x), Float64(y)))
Base.rem(x::LinearTakum16, y::LinearTakum16) = LinearTakum16(rem(Float64(x), Float64(y)))
Base.rem(x::LinearTakum32, y::LinearTakum32) = LinearTakum32(rem(Float64(x), Float64(y)))
Base.rem(x::LinearTakum64, y::LinearTakum64) = LinearTakum64(rem(Float128(x), Float128(y)))

Base.rem(x::Posit8, y::Posit8) = Posit8(rem(Float64(x), Float64(y)))
Base.rem(x::Posit16, y::Posit16) = Posit16(rem(Float64(x), Float64(y)))
Base.rem(x::Posit32, y::Posit32) = Posit32(rem(Float64(x), Float64(y)))
Base.rem(x::Posit64, y::Posit64) = Posit64(rem(Float128(x), Float128(y)))

# irrational conversion for bfloat16
BFloat16s.BFloat16(i::Irrational) = BFloat16(Float32(i))

# define integer conversion for microfloats
Integer(x::Floatmu{szE, szf}) where {szE, szf} = Integer(Float32(x))

# overwrite nameof for microfloats
function Base.nameof(::Type{Floatmu{szE, szf}}) where {szE, szf}
	return Symbol("Float" * string(1 + szE + szf) * "_" * string(szE))
end

end

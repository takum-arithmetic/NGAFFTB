# See LICENSE file for copyright and license details
# NGAFFTB - Next Generation Arithmetic FFT Benchmarks
.POSIX:
.SUFFIXES:
.SUFFIXES: .format .jl .output .output_sorted .sh

include config.mk

COMMON =\
	src/Crutches\
	src/Experiments\
	src/Float128Conversions\
	src/PDE\
	src/format\
	src/sort_csv\

EXPERIMENT =\
	src/fft_audios\
	src/fft_images\
	src/solve_pde-heat-00100\
	src/solve_pde-heat-01000\
	src/solve_pde-heat-05000\
	src/solve_pde-heat-10000\
	src/solve_pde-poisson-0_1\
	src/solve_pde-poisson-0_2\
	src/solve_pde-poisson-0_3\
	src/solve_pde-poisson-0_4\

GENERATOR =\
	src/generate_audio_dataset\
	src/generate_image_dataset\

all: $(EXPERIMENT:=.output_sorted)

src/generate_audio_dataset.output: src/generate_audio_dataset.sh config.mk Makefile
src/generate_image_dataset.output: src/generate_image_dataset.sh config.mk Makefile

src/fft_audios.output: src/fft_audios.jl src/Experiments.jl src/Float128Conversions.jl src/PDE.jl config.mk Makefile
src/fft_images.output: src/fft_images.jl src/Experiments.jl src/Float128Conversions.jl src/PDE.jl config.mk Makefile
src/solve_pde-heat-00100.output: src/solve_pde-heat-00100.jl src/Experiments.jl src/Float128Conversions.jl src/PDE.jl config.mk Makefile
src/solve_pde-heat-01000.output: src/solve_pde-heat-01000.jl src/Experiments.jl src/Float128Conversions.jl src/PDE.jl config.mk Makefile
src/solve_pde-heat-05000.output: src/solve_pde-heat-05000.jl src/Experiments.jl src/Float128Conversions.jl src/PDE.jl config.mk Makefile
src/solve_pde-heat-10000.output: src/solve_pde-heat-10000.jl src/Experiments.jl src/Float128Conversions.jl src/PDE.jl config.mk Makefile
src/solve_pde-poisson-0_1.output: src/solve_pde-poisson-0_1.jl src/Experiments.jl src/Float128Conversions.jl src/PDE.jl config.mk Makefile
src/solve_pde-poisson-0_2.output: src/solve_pde-poisson-0_2.jl src/Experiments.jl src/Float128Conversions.jl src/PDE.jl config.mk Makefile
src/solve_pde-poisson-0_3.output: src/solve_pde-poisson-0_3.jl src/Experiments.jl src/Float128Conversions.jl src/PDE.jl config.mk Makefile
src/solve_pde-poisson-0_4.output: src/solve_pde-poisson-0_4.jl src/Experiments.jl src/Float128Conversions.jl src/PDE.jl config.mk Makefile

src/fft_audios.output_sorted: src/fft_audios.output src/sort_csv.jl
src/fft_images.output_sorted: src/fft_images.output src/sort_csv.jl
src/solve_pde-heat-00100.output_sorted: src/solve_pde-heat-00100.output src/sort_csv.jl
src/solve_pde-heat-01000.output_sorted: src/solve_pde-heat-01000.output src/sort_csv.jl
src/solve_pde-heat-05000.output_sorted: src/solve_pde-heat-05000.output src/sort_csv.jl
src/solve_pde-heat-10000.output_sorted: src/solve_pde-heat-10000.output src/sort_csv.jl
src/solve_pde-poisson-0_1.output_sorted: src/solve_pde-poisson-0_1.output src/sort_csv.jl
src/solve_pde-poisson-0_2.output_sorted: src/solve_pde-poisson-0_2.output src/sort_csv.jl
src/solve_pde-poisson-0_3.output_sorted: src/solve_pde-poisson-0_3.output src/sort_csv.jl
src/solve_pde-poisson-0_4.output_sorted: src/solve_pde-poisson-0_4.output src/sort_csv.jl

.jl.format:
	@# work around JuliaFormatter not supporting tabs for indentation
	@# by unexpanding a very wide 16-blank-indent
	$(JULIA) $(JULIA_FLAGS) -- "src/format.jl" "$<" && unexpand -t 16 "$<" > "$<.temp" && mv -f "$<.temp" "$<" && touch "$@"

.sh.format:
	@# no-op

.jl.output:
	@# experiments print a list of output files, store it an output witness
	$(JULIA) $(JULIA_FLAGS) -- "$<" $(JULIA_SCRIPT_FLAGS) > "$@.temp" && mv -f "$@.temp" "$@"

.sh.output:
	@# shell scripts print a list of output files, store it an output witness
	$(SH) "$<" > "$@.temp" && mv -f "$@.temp" "$@"

.output.output_sorted:
	@# use the output witness files and process each .csv file contained
	@# into a .sorted.csv file, outputting another witness file
	@# (.output_sorted) containing the file names
	$(JULIA) $(JULIA_FLAGS) -- "src/sort_csv.jl" "$<" > "$@.temp" && mv -f "$@.temp" "$@"

clean:
	@# use the output witnesses to clean up the output files, except
	@# those from the generators
	for w in $(EXPERIMENT:=.output); do if [ -f "$$w" ]; then xargs rm -f < "$$w"; fi; done
	for w in $(EXPERIMENT:=.output_sorted); do if [ -f "$$w" ]; then xargs rm -f < "$$w"; fi; done
	for d in $(EXPERIMENT); do if [ -d "`basename "$$d"`" ]; then rmdir "out/`basename "$$d"`"; fi; done
	rm -f $(EXPERIMENT:=.output) $(EXPERIMENT:=.output.temp) $(EXPERIMENT:=.output_sorted) $(EXPERIMENT:=.output_sorted.temp)
	rm -f $(COMMON:=.format) $(EXPERIMENT:=.format)

clean-generated:
	@# remove the generated files using the output witnesses
	for w in $(GENERATOR:=.output); do if [ -f "$$w" ]; then xargs rm -f < "$$w"; fi; done

format: $(COMMON:=.format) $(EXPERIMENT:=.format) $(GENERATOR:=.format)

.PHONY: all clean format

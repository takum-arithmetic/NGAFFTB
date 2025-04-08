#!/bin/sh

# download the ESC-50 archive
wget -O "data/ESC-50.zip" https://github.com/karoldvl/ESC-50/archive/master.zip

# create output directory
mkdir -p "data/audio"

# extract the audio samples from the archive, discarding the zip-paths, and
# cutting the first two metadata output lines and "inflating:" from all
# subsequent lines from the output to get a clean output file list that is
# written to the output witness file. We use awk(1) to remove trailing
# whitespace
unzip -j -o "data/ESC-50.zip" 'ESC-50-master/audio/*' -d "data/audio/" | tail -n +3 | cut -c 14- | awk '{$1=$1};1' | sort

# remove the ESC-50 archive
rm "data/ESC-50.zip"

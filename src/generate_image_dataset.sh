#!/bin/sh

# download the DIV2K high-resolution training and validation archives
#wget -O "data/DIV2K_train_HR.zip" https://data.vision.ee.ethz.ch/cvl/DIV2K/DIV2K_train_HR.zip
#wget -O "data/DIV2K_valid_HR.zip" https://data.vision.ee.ethz.ch/cvl/DIV2K/DIV2K_valid_HR.zip
wget -O "data/DIV2K_train_LR_bicubic_X2.zip" https://data.vision.ee.ethz.ch/cvl/DIV2K/DIV2K_train_LR_bicubic_X2.zip
wget -O "data/DIV2K_valid_LR_bicubic_X2.zip" https://data.vision.ee.ethz.ch/cvl/DIV2K/DIV2K_valid_LR_bicubic_X2.zip

# create output directory
mkdir -p "data/image"

# extract the audio samples from the archive, discarding the paths and "inflating:"
# from the output to get a clean output file list. We use awk(1) to remove
# trailing whitespace and write the lists to a temporary file for later processing
#unzip -o -j "data/DIV2K_train_HR.zip" 'DIV2K_train_HR/*' -d "data/image" | tail -n +3 | cut -c 14- | awk '{$1=$1};1' > "out/generate_image_dataset.tmp"
#unzip -o -j "data/DIV2K_valid_HR.zip" 'DIV2K_valid_HR/*' -d "data/image" | tail -n +3 | cut -c 14- | awk '{$1=$1};1' >> "out/generate_image_dataset.tmp"
unzip -o -j "data/DIV2K_train_LR_bicubic_X2.zip" 'DIV2K_train_LR_bicubic/X2/*' -d "data/image" | tail -n +3 | cut -c 14- | awk '{$1=$1};1' > "out/generate_image_dataset.tmp"
unzip -o -j "data/DIV2K_valid_LR_bicubic_X2.zip" 'DIV2K_valid_LR_bicubic/X2/*' -d "data/image" | tail -n +3 | cut -c 14- | awk '{$1=$1};1' >> "out/generate_image_dataset.tmp"

# We sort the temporary file and only then print its contents, the sorted
# file list, to standard output
sort < "out/generate_image_dataset.tmp"

# remove the temporary file
rm "out/generate_image_dataset.tmp"

# remove the ESC-50 archive
#rm "data/DIV2K_train_HR.zip"
#rm "data/DIV2K_valid_HR.zip"
rm "data/DIV2K_train_LR_bicubic_X2.zip"
rm "data/DIV2K_valid_LR_bicubic_X2.zip"

#!/bin/bash
###
# Build the DP application and add it to the FPGA bitstream
# (c) 2026 by Parretto B.V.
#
# Requirements:
# - Arm GNU toolchain aarch64-none-elf (in the PATH, or downloaded by this script)
# - Quartus Prime Pro (QUARTUS_ROOTDIR set, or quartus_pfg in the PATH)
# - cmake and ninja
#
# Output: dp_ref_alt_ag5e_065a_mdk_hps.sof in the synthesis output directory.
# This bitstream contains both the FPGA image and the HPS application and can be programmed with JTAG.
###

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SYN_DIR=$SCRIPT_DIR/../../../gateware/syn/ag5e_065a_mdk/output_files
PROJECT=dp_ref_alt_ag5e_065a_mdk

# Toolchain
# Always use the Arm GNU toolchain, as Altera does.
# Other aarch64-none-elf toolchains (for example the one in Vitis) link a different startup code
# and the application doesn't start at address 0.
TOOLCHAIN=arm-gnu-toolchain-13.2.Rel1-x86_64-aarch64-none-elf
if [ ! -d "$SCRIPT_DIR/../../tools/$TOOLCHAIN" ]; then
    mkdir -p "$SCRIPT_DIR/../../tools"
    wget -P "$SCRIPT_DIR/../../tools" https://developer.arm.com/-/media/Files/downloads/gnu/13.2.rel1/binrel/$TOOLCHAIN.tar.xz
    tar xf "$SCRIPT_DIR/../../tools/$TOOLCHAIN.tar.xz" -C "$SCRIPT_DIR/../../tools"
    rm -f "$SCRIPT_DIR/../../tools/$TOOLCHAIN.tar.xz"
fi
export PATH=$SCRIPT_DIR/../../tools/$TOOLCHAIN/bin:$PATH
export CROSS_COMPILE=aarch64-none-elf-

# Quartus
if [ -n "$QUARTUS_ROOTDIR" ]; then
    export PATH=$QUARTUS_ROOTDIR/bin:$PATH
fi

# Application
cmake -S "$SCRIPT_DIR" -B "$SCRIPT_DIR/bin" -GNinja -DCMAKE_BUILD_TYPE=Release
cmake --build "$SCRIPT_DIR/bin"

# Bitstream
# The SDM loads the application into the HPS on-chip RAM after the FPGA is configured.
quartus_pfg -c "$SYN_DIR/$PROJECT.sof" "$SYN_DIR/${PROJECT}_hps.sof" -o hps_path="$SCRIPT_DIR/bin/dp_app.hex"

echo "Bitstream: $SYN_DIR/${PROJECT}_hps.sof"

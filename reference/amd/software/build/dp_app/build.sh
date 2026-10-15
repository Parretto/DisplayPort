#!/bin/bash
###
# Build the DP application
# (c) 2026 by Parretto B.V.
#
# Requirements:
# - Arm GNU toolchain aarch64-none-elf (the one of the Altera reference design, or downloaded by this script)
# - cmake and ninja
#
# Usage: build.sh [board]     board: zu4cg_xu6_st1 (default) or zu9eg_zcu102
#
# Output: bin/<board>/dp_app.elf, loaded into the on-chip memory by the debugger (see reference/amd/README.md)
###

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
BOARD=${1:-zu4cg_xu6_st1}

# Toolchain
# The Arm GNU toolchain, as for the Altera reference design.
TOOLCHAIN=arm-gnu-toolchain-13.2.Rel1-x86_64-aarch64-none-elf
TOOLS=$SCRIPT_DIR/../../tools
if [ -d "$SCRIPT_DIR/../../../../altera/software/tools/$TOOLCHAIN" ]; then
    TOOLS=$SCRIPT_DIR/../../../../altera/software/tools
elif [ ! -d "$TOOLS/$TOOLCHAIN" ]; then
    mkdir -p "$TOOLS"
    wget -P "$TOOLS" https://developer.arm.com/-/media/Files/downloads/gnu/13.2.rel1/binrel/$TOOLCHAIN.tar.xz
    tar xf "$TOOLS/$TOOLCHAIN.tar.xz" -C "$TOOLS"
    rm -f "$TOOLS/$TOOLCHAIN.tar.xz"
fi
export PATH=$TOOLS/$TOOLCHAIN/bin:$PATH

cmake -S "$SCRIPT_DIR" -B "$SCRIPT_DIR/bin/$BOARD" -GNinja -DCMAKE_BUILD_TYPE=Release -DPRT_BOARD=$BOARD
cmake --build "$SCRIPT_DIR/bin/$BOARD"

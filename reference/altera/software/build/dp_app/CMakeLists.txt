###
# DP application for the Altera Agilex 5 E-Series 065A Modular Development Kit
# (c) 2026 by Parretto B.V.
###

cmake_minimum_required(VERSION 3.5...3.28)

include(FetchContent)

set(BUILD_TESTS OFF)

# Altera baremetal drivers
FetchContent_Declare(
    alterametal
    GIT_REPOSITORY https://github.com/altera-fpga/baremetal-drivers.git
    GIT_TAG QPDS25.1_REL_GSRD_PR
)
FetchContent_MakeAvailable(alterametal)

project(dp_app C CXX ASM)

set(SRC ${CMAKE_CURRENT_SOURCE_DIR}/../../src)

# Shared DisplayPort software (same sources as the other reference designs)
set(DP_SW ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../software)

add_executable(dp_app.elf)

target_sources(dp_app.elf
    PRIVATE
        ${SRC}/prt_dp_app.c
        ${SRC}/prt_hps_ccu.c
        ${SRC}/prt_hps_clk.c
        ${SRC}/prt_hps_irq.c
        ${SRC}/prt_hps_vec.S
        ${SRC}/prt_phy_alt_gts.c
        ${SRC}/prt_pll_alt_hvio.c
        ${SRC}/prt_log.c
        ${SRC}/prt_uart.c
        ${DP_SW}/src/app/prt_dp_drv.c
        ${DP_SW}/src/app/prt_dp_fmt.c
        ${DP_SW}/src/app/prt_dp_edid.c
        ${DP_SW}/src/app/prt_i2c.c
        ${DP_SW}/src/vtb/prt_vtb.c
)

# The shared driver is not built with warnings as errors
set_source_files_properties(${DP_SW}/src/app/prt_dp_drv.c ${DP_SW}/src/app/prt_dp_edid.c ${DP_SW}/src/vtb/prt_vtb.c PROPERTIES COMPILE_OPTIONS "-Wno-error")

target_include_directories(dp_app.elf
    PRIVATE
        ${SRC}
        ${DP_SW}/src/app
        ${DP_SW}/src/vtb
        ${DP_SW}/src/shared
        ${DP_SW}/pm
)

# FSBL_EXECUTION: the application runs from the on-chip RAM in place of the first stage boot loader
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    target_compile_options(dp_app.elf PRIVATE -DFSBL_EXECUTION ${DEFAULT_C_FLAGS_DEBUG})
else()
    target_compile_options(dp_app.elf PRIVATE -DFSBL_EXECUTION ${DEFAULT_C_FLAGS_RELEASE})
endif()

target_link_libraries(dp_app.elf
    PRIVATE
        alterametal
)

# On-chip RAM linker script
target_link_options(dp_app.elf
    PRIVATE
        -T${alterametal_SOURCE_DIR}/build/aarch64/core0_ocram.ld
        --specs=nosys.specs -mstrict-align
)

# Binary and Intel hex image for the SDM
add_custom_command(TARGET dp_app.elf POST_BUILD
    COMMAND ${ToolchainPrefix}objcopy -O binary dp_app.elf dp_app.bin
    COMMAND ${ToolchainPrefix}objcopy -I binary -O ihex --change-addresses 0x0 dp_app.bin dp_app.hex
    COMMAND ${ToolchainPrefix}size dp_app.elf
)

###
# DP application for the AMD Zynq UltraScale+ reference designs
# PRT_BOARD: zu4cg_xu6_st1 (Enclustra Mercury+ XU6 on the Mercury+ ST1, default) or zu9eg_zcu102 (AMD ZCU102)
# (c) 2026 by Parretto B.V.
###

cmake_minimum_required(VERSION 3.5...3.28)

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER aarch64-none-elf-gcc)
set(CMAKE_ASM_COMPILER aarch64-none-elf-gcc)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

project(dp_app C ASM)

set(PRT_BOARD "zu4cg_xu6_st1" CACHE STRING "Reference design board")
string(TOUPPER "PRT_BOARD_${PRT_BOARD}" PRT_BOARD_DEF)

set(SRC ${CMAKE_CURRENT_SOURCE_DIR}/../../src)

# Shared DisplayPort software (same sources as the other reference designs)
set(DP_SW ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../software)

# Tentiva driver (same as the Lattice reference designs)
set(TENTIVA_DRV ${DP_SW}/src/tentiva)

add_executable(dp_app.elf)

target_sources(dp_app.elf
    PRIVATE
        ${SRC}/prt_zu_start.S
        ${SRC}/prt_zu_vec.S
        ${SRC}/prt_zu_mmu.c
        ${SRC}/prt_zu_irq.c
        ${SRC}/prt_zu_tmr.c
        ${SRC}/prt_zu_sys.c
        ${SRC}/prt_uart.c
        ${SRC}/prt_log.c
        ${SRC}/prt_phy_amd_gth.c
        ${SRC}/prt_dp_app.c
        ${DP_SW}/src/app/prt_dp_drv.c
        ${DP_SW}/src/app/prt_dp_fmt.c
        ${DP_SW}/src/app/prt_dp_edid.c
        ${DP_SW}/src/app/prt_i2c.c
        ${DP_SW}/src/vtb/prt_vtb.c
        ${TENTIVA_DRV}/prt_tentiva.c
        ${TENTIVA_DRV}/prt_mcdp6150.c
        ${TENTIVA_DRV}/prt_tdp142.c
        ${TENTIVA_DRV}/prt_tdp2004.c
        ${TENTIVA_DRV}/prt_tdp1204.c
        ${TENTIVA_DRV}/prt_tmds1204.c
)

# The shared drivers are not built with warnings as errors
set_source_files_properties(
    ${DP_SW}/src/app/prt_dp_drv.c ${DP_SW}/src/app/prt_dp_edid.c ${DP_SW}/src/vtb/prt_vtb.c
    ${TENTIVA_DRV}/prt_tentiva.c ${TENTIVA_DRV}/prt_mcdp6150.c ${TENTIVA_DRV}/prt_tdp142.c ${TENTIVA_DRV}/prt_tdp2004.c
    ${TENTIVA_DRV}/prt_tdp1204.c ${TENTIVA_DRV}/prt_tmds1204.c
    PROPERTIES COMPILE_OPTIONS "-Wno-error;-Wno-implicit-function-declaration;-Wno-int-conversion;-Wno-incompatible-pointer-types")

# The Tentiva driver comes before the shared sources, which have an older copy
target_include_directories(dp_app.elf
    PRIVATE
        ${SRC}
        ${TENTIVA_DRV}
        ${DP_SW}/src/app
        ${DP_SW}/src/vtb
        ${DP_SW}/src/shared
        ${DP_SW}/pm
)

# The startup code runs before the MMU is on (all memory is device memory), so no unaligned accesses
target_compile_definitions(dp_app.elf PRIVATE ${PRT_BOARD_DEF})
target_compile_options(dp_app.elf PRIVATE -mcpu=cortex-a53 -mstrict-align -O2 -g -Wall -ffunction-sections -fdata-sections)

target_link_options(dp_app.elf
    PRIVATE
        -T${CMAKE_CURRENT_SOURCE_DIR}/ocm.ld
        -nostartfiles --specs=nosys.specs -Wl,--gc-sections -Wl,-Map=dp_app.map
)

add_custom_command(TARGET dp_app.elf POST_BUILD
    COMMAND aarch64-none-elf-size dp_app.elf
)

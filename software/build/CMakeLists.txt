cmake_minimum_required(VERSION 3.3)

message (STATUS "DisplayPort application build script")
message (STATUS "(c) 2012-2024 by Parretto B.V.")
message (STATUS "Vendor: ${VENDOR}")
message (STATUS "Board: ${BOARD}")

if (("${VENDOR}" STREQUAL "") OR ("${BOARD}" STREQUAL "") OR ("${GCC}" STREQUAL ""))
    message (FATAL_ERROR "\nmissing argument\n
        cmake . -DVENDOR={AMD|LSC|INT} -DBOARD={AMD_ZCU102|LSC_LFCPNX|INT_C10GX|INT_A10GX|TB_A7_200T_IMG} -DGCC=<gcc toolchain>")
endif()

project ("dp_app" C ASM)
set (TARGET ${PROJECT_NAME}_${BOARD})
string (TOLOWER "${TARGET}" TARGET)

set (CMAKE_ASM_COMPILER ${GCC}gcc)
set (CMAKE_AR ${GCC}ar)
set (CMAKE_ASM_COMPILER ${GCC}gcc)
set (CMAKE_C_COMPILER ${GCC}gcc)
set (CMAKE_CXX_COMPILER ${GCC}g++)
set (CMAKE_OBJCOPY ${GCC}objcopy)
set (CMAKE_SIZE ${GCC}size)

set (CMAKE_SYSTEM_NAME          Generic)
set (CMAKE_SYSTEM_PROCESSOR     rv32i)
set (CMAKE_CROSSCOMPILING TRUE)
set (CMAKE_CXX_COMPILER_WORKS TRUE)
set (CMAKE_C_COMPILER_WORKS TRUE)
set (CMAKE_ASM_COMPILER_WORKS TRUE)

# get rid of -rdynamic error
set (CMAKE_SHARED_LIBRARY_LINK_C_FLAGS) 
set (CMAKE_RUNTIME_OUTPUT_DIRECTORY ./bin)

# Compiler flags
set (CMAKE_C_FLAGS "-march=rv32i -mabi=ilp32 -O1 -fno-tree-loop-distribute-patterns -ffreestanding -Bstatic -fno-builtin-memset -nostdlib -fno-lto")

# Set executable sources
set (EXE_SRC 
    start.S
    ../src/app/prt_irq.c
    ../src/app/prt_printf.c
    ../src/app/prt_log.c
    ../src/app/prt_pio.c
    ../src/app/prt_uart.c
    ../src/app/prt_tmr.c
    ../src/app/prt_i2c.c
    ../src/app/prt_rc22504a.c
    ../src/app/prt_mcdp6150.c
    ../src/app/prt_mcdp6000.c
    ../src/app/prt_tdp142.c
    ../src/app/prt_tdp2004.c
    ../src/app/prt_tentiva.c
    ../src/vtb/prt_vtb.c
    ../src/app/prt_dp_edid.c
    ../src/app/prt_dp_drv.c
    ../src/app/prt_dp_app.c
) 

# Add PHY driver
# AMD ZCU102 
if ("${BOARD}" STREQUAL "AMD_ZCU102")
    list (APPEND EXE_SRC ../src/app/prt_phy_amd_us_gth.c)

# Lattice CertusPro-NX
elseif ("${BOARD}" STREQUAL "LSC_LFCPNX")
    list (APPEND EXE_SRC ../src/app/prt_phy_lsc_cpnx.c)

# Intel Cyclone 10GX
elseif ("${BOARD}" STREQUAL "INT_C10GX")
    list (APPEND EXE_SRC ../src/app/prt_phy_int_10gx.c)

# Intel Arria 10GX
elseif ("${BOARD}" STREQUAL "INT_A10GX")
    list (APPEND EXE_SRC ../src/app/prt_phy_int_10gx.c)

# Inrevium TB-A7-200T-IMG
elseif ("${BOARD}" STREQUAL "TB_A7_200T_IMG")
    list (APPEND EXE_SRC ../src/app/prt_phy_amd_a7_gtp.c)

else()
    message (FATAL_ERROR "Invalid board setup")

endif()

set (INC_DIR
    ../src/app
    ../src/vtb
    ../src/lib
)

# Executable
add_executable (${TARGET}.elf ${EXE_SRC})

target_include_directories (${TARGET}.elf PRIVATE ${INC_DIR})

# Set board and enable DPTX and DPRX interrupt handlers
target_compile_definitions (${TARGET}.elf PRIVATE VENDOR=VENDOR_${VENDOR} BOARD=BOARD_${BOARD} PRT_IRQ_DPTX PRT_IRQ_DPRX)

# Linker
set (LINKER_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/sections.lds")
set (CMAKE_EXE_LINKER_FLAGS  "${CMAKE_EXE_LINKER_FLAGS} -fno-exceptions -nostartfiles -T ${LINKER_SCRIPT}")
set_target_properties(${TARGET}.elf PROPERTIES LINK_DEPENDS "${LINKER_SCRIPT}")

# Generate verilog output
add_custom_command (
    TARGET ${TARGET}.elf
    POST_BUILD
    COMMAND ${CMAKE_OBJCOPY} -O verilog ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${TARGET}.elf ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${TARGET}.v
)

# Generate DP application memory files
add_custom_command (
    TARGET ${TARGET}.elf
    POST_BUILD
    COMMAND perl gen_ram.pl --verilog=${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${TARGET}.v --gen_mem
)

# Generate MIF file for Intel 
if ("${VENDOR}" STREQUAL "INT")
add_custom_command (
    TARGET ${TARGET}.elf
    POST_BUILD
    COMMAND perl gen_ram.pl --verilog=${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${TARGET}.v --gen_mif
)
endif ()

# Report size
add_custom_command (
    TARGET ${TARGET}.elf
    POST_BUILD
	COMMAND ${CMAKE_SIZE} ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${TARGET}.elf
)

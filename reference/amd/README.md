# AMD reference designs

DisplayPort transmitter (DPTX) and receiver (DPRX) on AMD Zynq UltraScale+ with the Parretto Tentiva FMC board.

| Board | Folder | Device |
|---|---|---|
| Enclustra Mercury+ XU6 on the Mercury+ ST1 base board | `zu4cg_xu6_st1` | xczu4cg-sfvc784-1-e |
| AMD ZCU102 | `zu9eg_zcu102` | xczu9eg-ffvb1156-2-e |

Both designs support up to HBR3 (8.1 Gbps per lane) on four lanes, for the transmitter and the receiver.
The application runs bare metal on Cortex-A53 #0 from the on-chip memory (OCM); the DDR memory is not used.

# Hardware
- The Tentiva FMC board with a DP TX card and a DP RX card. On the ZCU102 the Tentiva is on FMC HPC0.
- The console is the UART of the Tentiva board (USB on the Tentiva). Use a terminal program with 115200 baud, 8N1.
- JTAG: the ZCU102 uses its on-board USB JTAG. The XU6 uses the Alinx JTAG cable (it enumerates as a Digilent JTAG-HS1).

# Requirements
- Vivado 2025.1 for the gateware.
- Vitis 2025.2 (`xsdb`) for programming.
- The Arm GNU toolchain 13.2.Rel1 (`aarch64-none-elf`), cmake and ninja for the application.
  The build script downloads the toolchain when it is not present.

# Folders
```
gateware/ref/<board>/       Top level, constraints, block design (dp_soc_*.tcl), transceiver IP (gth_ip.tcl), project script
software/src/               Application (menu, Tentiva, PHY driver, interrupts, timer, UART, start-up code)
software/build/dp_app/      Application build (CMake)
```
The DP host driver, the video toolbox driver, the Tentiva drivers and the policy maker images are shared
by all reference designs, they are in `software/` at the top of the repository.

# Building
## Gateware
```
mkdir -p reference/amd/gateware/syn/<board>
cd reference/amd/gateware/syn/<board>
vivado -mode batch -source ../../ref/<board>/build_proj.tcl
```
The script creates the project, the block design and the IP, and runs synthesis, implementation and bitstream generation.
The output in the synthesis folder:
- `dp_ref_amd_<board>.bit`, the bitstream
- `dp_ref_amd_<board>.xsa`, the hardware platform with the initialization of the processing system (`psu_init.tcl`)
- `timing_summary.rpt` and `utilization.rpt`

## Application
```
reference/amd/software/build/dp_app/build.sh <board>
```
The output is `reference/amd/software/build/dp_app/bin/<board>/dp_app.elf`.
`<board>` is `zu4cg_xu6_st1` (default) or `zu9eg_zcu102`.

# Programming
The processing system is initialized by the debugger, so the board is programmed with the Vitis `xsdb` console.
Extract `psu_init.tcl` from the hardware platform first (`unzip dp_ref_amd_<board>.xsa psu_init.tcl`),
then run in `xsdb`:
```
connect
targets -set -nocase -filter {name =~ "*PSU*"}
rst -system
targets -set -nocase -filter {name =~ "*PL*"}
fpga -file dp_ref_amd_<board>.bit
targets -set -nocase -filter {name =~ "*PSU*"}
source psu_init.tcl
psu_init
psu_ps_pl_isolation_removal
psu_ps_pl_reset_config
targets -set -nocase -filter {name =~ "*A53*#0"}
rst -processor -clear-registers
dow dp_app.elf
con
```
This resets the system, configures the FPGA, initializes the processing system, removes the isolation between
the processing system and the FPGA, and loads and starts the application on Cortex-A53 #0.
The design runs until the next power cycle; it is not written to the flash memory.

# Operation
At start-up the application prints its banner and configures the Tentiva, the PHY, the video toolbox, the DPTX and the DPRX.
Connect a DP sink to the DP TX card and a DP source to the DP RX card.

The transmitter starts with a colorbar test pattern in the best video format of the sink's EDID that fits the link.
Commands on the console:

| Key | Function |
|---|---|
| `z` | Colorbar test pattern on the DPTX: select the video format from a list that shows the support of the sink and the link |
| `x` | Pass-through: the video of the DPRX goes to the DPTX |
| `q` / `a` | Ping the DPTX / DPRX policy maker |
| `e` / `d` | Status of the DPTX / DPRX |
| `f` | DPRX hot plug pulse |
| `l` | Video toolbox status |

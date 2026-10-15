# Lattice reference designs

DisplayPort transmitter (DPTX) and receiver (DPRX) on Lattice FPGAs with the Parretto Tentiva FMC board.

| Board | Folder | Device | Maximum link rate |
|---|---|---|---|
| Lattice Avant G70 Versa board | `lav_g70_versa_evn` | LAV-AT-X70-1LFG1156C | HBR3 (8.1 Gbps per lane) |
| Lattice CertusPro-NX Evaluation board | `lfcpnx_evn` | LFCPNX-100-9LFG672C | HBR2 (5.4 Gbps per lane) |

Both designs use four lanes for the transmitter and the receiver.
The application runs on the RISC-V processor of the Propel SoC, from the SoC memory.

# Hardware
- The Tentiva FMC board with a DP TX card and a DP RX card, on the FMC connector of the evaluation board.
  On the Avant board the application selects the FMC channel of the I2C mux.
- The console is the UART of the Tentiva board (USB on the Tentiva). Use a terminal program with 115200 baud, 8N1.
- Programming with the USB cable of the evaluation board.

# Requirements
- Lattice Radiant 2026.1.
- Lattice Propel 2026.1 (Propel Builder for the SoC, Propel SDK for the application).

# Folders
```
gateware/propel/            Propel SoC scripts (create_dp_soc_lav.tcl, create_dp_soc_lfcpnx.tcl)
gateware/ref/<board>/       Top level, constraints (.sdc, .pdc), PHY and PLL configuration, project script
software/src/               Application (menu, Tentiva, PHY drivers, utilities)
software/workspace/         Propel SDK workspace: dp_app_lfcpnx (CertusPro-NX) and dp_app_lav (Avant)
```
The DP host driver, the video toolbox driver, the Tentiva drivers and the policy maker images are shared
by all reference designs, they are in `software/` at the top of the repository. The workspace projects contain
a copy of the sources they use.

# Building
The steps for the Avant board, with the CertusPro-NX names in brackets.

## 1. Propel SoC
```
cd reference/lsc/gateware/propel
propelbldc < create_dp_soc_lav.tcl          (create_dp_soc_lfcpnx.tcl)
```
This creates the SoC `dp_soc_lav` (`dp_soc_lfcpnx`) in `gateware/propel`.

## 2. Application
1. Start Propel SDK with the workspace `reference/lsc/software/workspace`.
2. Import the project `dp_app_lav` (`dp_app_lfcpnx`): File > Import > Existing Projects into Workspace.
3. Generate the BSP of the project from the SoC: `gateware/propel/dp_soc_lav/sge/sys_env.xml`
   (`dp_soc_lfcpnx`).
4. Build the project. The memory image is `Debug/dp_app_lav.mem` (`Debug/dp_app_lfcpnx.mem`).

## 3. Gateware
```
mkdir -p reference/lsc/gateware/syn/lav_g70_versa_evn       (lfcpnx_evn)
cd reference/lsc/gateware/syn/lav_g70_versa_evn
radiantc ../../ref/lav_g70_versa_evn/build_proj.tcl
```
The script creates the Radiant project, generates the Lattice IP and runs synthesis, map, place & route and
the bitstream generation. The bitstream is in `impl1/`.

# Programming
Program the bitstream with the Radiant Programmer. Then load the application in one of two ways:
- With the Propel SDK debugger: run or debug the project (the launch configuration `dp_app_lav.launch`,
  `dp_app_lfcpnx.launch` for the CertusPro-NX). The debugger loads the application into the SoC memory over JTAG and starts it.
  The application has to be loaded again after every power cycle.
- In the bitstream: the SoC memory (`system0`) is initialized with `software/workspace/dp_app_lav/Debug/dp_app_lav.mem`
  (`dp_app_lfcpnx/Debug/dp_app_lfcpnx.mem`). Propel puts the image into the SoC when it generates the SoC, so after building
  the application generate the SoC again in Propel Builder and rebuild the bitstream (step 3). The application
  then starts with the FPGA.

# Operation
At start-up the application prints its banner and configures the Tentiva, the PHY, the video toolbox, the DPTX and the DPRX.
Connect a DP sink to the DP TX card and a DP source to the DP RX card.

The transmitter starts with a colorbar test pattern in the best video format of the sink's EDID that fits the link.
Commands on the console:

| Key | Function |
|---|---|
| `z` | Colorbar test pattern on the DPTX: select the video format from a list that shows the support of the sink and the link |
| `x` | Pass-through: the video of the DPRX goes to the DPTX |
| `c` | Select the video resolutions of the DPRX EDID |
| `q` / `a` | Ping the DPTX / DPRX policy maker |
| `e` / `d` | Status of the DPTX / DPRX |
| `f` | DPRX hot plug: unplug, plug or pulse |
| `l` | Video toolbox status |

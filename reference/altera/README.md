# Altera reference design

DisplayPort transmitter (DPTX) and receiver (DPRX) on the Altera Agilex 5 E-Series 065A Modular Development Kit
(device A5ED065AB32AE1V).

The design supports up to HBR3 (8.1 Gbps per lane) on four lanes, for the transmitter and the receiver.
The transceivers are the GTS transceivers of bank 4A.
The application runs bare metal on the HPS (Cortex-A55) from the on-chip RAM.

# Hardware
- The DP TX and DP RX connectors of the development kit (with PI2DPX2063 redrivers, set by the application over I2C).
- The console is the HPS UART, on the USB port of the modular board. Use a terminal program with 115200 baud, 8N1.
- JTAG: the USB-Blaster of the modular board, or else the one of the carrier board.

# Requirements
- Quartus Prime Pro 26.1.1, with Platform Designer. Select the installation with `QUARTUS_ROOTDIR`.
- The Arm GNU toolchain 13.2.Rel1 (`aarch64-none-elf`), cmake and ninja for the application.
  The build script downloads the toolchain when it is not present.
  Use this toolchain: other `aarch64-none-elf` toolchains link a different start-up code.

# Folders
```
gateware/ref/ag5e_065a_mdk/     Top level, timing constraints, Platform Designer system (dp_soc_ag5e.tcl),
                                transceiver and video PLL IP (gts_ip.tcl, vid_pll_ip.tcl), project script
gateware/ip/prt_apb_exp/        APB export component for Platform Designer
gateware/src/                   Video PLL reconfiguration
software/src/                   Application (menu, HPS clocks and cache coherency, interrupts, PHY and PLL drivers, UART)
software/build/dp_app/          Application build (CMake)
```
The DP host driver, the video toolbox driver and the policy maker images are shared by all reference designs,
they are in `software/` at the top of the repository.

# Building
## Gateware
```
mkdir -p reference/altera/gateware/syn/ag5e_065a_mdk
cd reference/altera/gateware/syn/ag5e_065a_mdk
quartus_sh -t ../../ref/ag5e_065a_mdk/build_proj.tcl
```
The script creates the project, generates the Platform Designer system and the IP, and compiles the design.
The bitstream is `output_files/dp_ref_alt_ag5e_065a_mdk.sof`.

## Application
```
reference/altera/software/build/dp_app/build.sh
```
The script builds the application and adds it to the bitstream. The result,
`gateware/syn/ag5e_065a_mdk/output_files/dp_ref_alt_ag5e_065a_mdk_hps.sof`,
contains the FPGA image and the HPS application. After the FPGA is configured, the SDM loads the application into
the HPS on-chip RAM. Build the gateware first.

# Programming
Program `dp_ref_alt_ag5e_065a_mdk_hps.sof` over JTAG with the Quartus Programmer. The FPGA is the second device
in the JTAG chain, after the Arm DAP. From the command line:
```
jtagconfig
quartus_pgm -c <cable> -m jtag -o "p;dp_ref_alt_ag5e_065a_mdk_hps.sof@2"
```
`jtagconfig` lists the cables; `<cable>` is the number or the name of the USB-Blaster.
The design runs until the next power cycle. When the HPS stops responding, power cycle the board.

# Operation
At start-up the application prints its banner, initializes the HPS and configures the redrivers, the PHY,
the video toolbox, the DPTX and the DPRX.
Connect a DP sink to the DP TX connector and a DP source to the DP RX connector.

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
| `s` | PHY status |
| `v` | DPTX voltage swing and pre-emphasis |

# DisplayPort

The DisplayPort IP-core is a resource optimized DisplayPort solution for FPGA devices.
The DP IP-core autonomously handles the link training and the bring up of the video stream.
The thin host driver has a simple API, which is used by the application to interact with the DP IP-core.

# Features
- DisplayPort 1.4a
- Source (DPTX) and Sink (DPRX)
	- RBR, HBR, HBR2 and HBR3 line rates
	- Support for 1, 2 and 4 DP lanes
	- Native video and AXI stream video interfaces
	- Single Stream Transport mode (SST)
	- Dual and quad pixels per clock
	- 8 & 10-bits video
	- Secondary data packet interface for audio and meta data transport, with parity check in the sink

- Video toolbox (VTB)
	- Timing generator
	- Test pattern generator
	- Clock recovery

# Reference designs
The reference designs run the application on the processor of the FPGA vendor. The AMD and Lattice designs use
the Tentiva FMC system, the Altera design the DP connectors of the development kit.
Every vendor folder has a README with the hardware setup, the tools and the build and programming steps:
[AMD](reference/amd/README.md), [Altera](reference/altera/README.md) and [Lattice](reference/lsc/README.md).

| Vendor | Board | Folder |
|---|---|---|
| AMD | ZCU102 (Zynq UltraScale+) | `reference/amd/gateware/ref/zu9eg_zcu102` |
| AMD | Enclustra Mercury+ XU6 on the Mercury+ ST1 (Zynq UltraScale+) | `reference/amd/gateware/ref/zu4cg_xu6_st1` |
| Altera | Agilex 5 E-Series 065A Modular Development Kit | `reference/altera/gateware/ref/ag5e_065a_mdk` |
| Lattice | CertusPro-NX evaluation board | `reference/lsc/gateware/ref/lfcpnx_evn` |
| Lattice | Avant G70 Versa board | `reference/lsc/gateware/ref/lav_g70_versa_evn` |

A PHY for the AMD Artix-7 GTP transceivers is available in `gateware/src/misc/dp_phy_a7_gtp.sv`.

# Repository structure
```
gateware/src/      IP-core sources
    tx/            DisplayPort transmitter (DPTX)
    rx/            DisplayPort receiver (DPRX)
    pm/            Policy maker (inside the DPTX and DPRX)
    vtb/           Video toolbox
    lib/           Libraries
    misc/          Shared blocks
software/src/      Host driver (app), video toolbox driver (vtb), Tentiva drivers (tentiva)
software/pm/       Policy maker firmware images
reference/         Reference designs per vendor (gateware, application and scripts)
```

The policy maker firmware is delivered as a pre-compiled image. The application loads it into
the policy makers at start up (`software/pm`).

# License key
Without a license key the DP IP-cores stop after one hour; an eval license key extends this to eight hours.
The application passes the key to the core with `prt_dp_lic()` (see the reference designs, `dptx_lic` and `dprx_lic`).
Contact Parretto for an eval or a production license key.

# Single-file IP-cores
Every release on GitHub also contains the IP-cores as single files (transmitter, receiver,
policy maker and video toolbox), together with the libraries they need.
This is the easiest way to add the DP IP-core to an FPGA project.

# Building a reference design
Create the synthesis folder of the board and run the project script from there, for example for the ZCU102:
```
mkdir -p reference/amd/gateware/syn/zu9eg_zcu102
cd reference/amd/gateware/syn/zu9eg_zcu102
vivado -mode batch -source ../../ref/zu9eg_zcu102/build_proj.tcl
```
- AMD: `vivado -mode batch -source ../../ref/<board>/build_proj.tcl`. Build the application with
  `reference/amd/software/build/dp_app/build.sh <board>` and program the board with the Vitis `xsdb` console.
- Altera: `quartus_sh -t ../../ref/ag5e_065a_mdk/build_proj.tcl`. The application is built and added to the
  bitstream with `reference/altera/software/build/dp_app/build.sh`, programming with the Quartus Programmer.
- Lattice:
  1. Create the Propel SoC: in `reference/lsc/gateware/propel` run `propelbldc < create_dp_soc_lfcpnx.tcl`
     (CertusPro-NX) or `propelbldc < create_dp_soc_lav.tcl` (Avant).
  2. Open the workspace `reference/lsc/software/workspace` in Lattice Propel SDK, import the project
     (`dp_app_lfcpnx` or `dp_app_lav`), generate its BSP from the SoC (`gateware/propel/<soc>/sge/sys_env.xml`) and build it.
  3. Run `radiantc ../../ref/<board>/build_proj.tcl` and program the bitstream with the Radiant Programmer.
  4. Load the application with the Propel SDK debugger, or put it in the bitstream: generate the SoC again
     in Propel Builder, so its memory contains the application image, and rebuild the bitstream.

The README of the vendor folder has the details.

The output of the vendor tools (Propel SoC and BSP, Platform Designer system, Vivado block design and IP)
is not in the repository: the project scripts create it.

# Documentation
The documentation is available online at https://docs.parretto.com

# License
This License will apply to the use of the IP-core (as defined in the License).
Please read the License carefully so that you know what your rights and obligations are when using the IP-core.
The acceptance of this License constitutes a valid and binding agreement between Parretto and you for the use of the IP-core.
If you download and/or make any use of the IP-core you agree to be bound by this License.
The License is available for download at www.parretto.com/license
Parretto grants you, as the Licensee, a free, non-exclusive, non-transferable, limited right to use the IP-core
solely for internal business purposes for the term and conditions of the License.
You are also allowed to create Modifications for internal business purposes, but explicitly only under the conditions of art. 3.2.
You are, however, obliged to pay the License Fees to Parretto for the use of the IP-core, or any Modification, in, or embodied in,
a physical or non-tangible product or service that has substantial commercial, industrial or non-consumer uses.

The version with the RISC-V application processor is available under the tag `v1.0-riscv`.

# Contact
Send an email to dp@parretto.com

(c) 2021 - 2026 by Parretto B.V.

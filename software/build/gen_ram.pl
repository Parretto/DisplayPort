
print "\nGenerate RAM\n";
print "This tool reads a verilog memory file.\n";
print "It writes a Xilinx Memory file and Quartus MIF file\n";
print "Written by Marco Groeneveld\n";
print "(c) 2013 by Logic & More B.V.\n";
print "(c) 2023-2024 by Parretto B.V.\n";

my $verilog_path;
my $verilog_name;
my $tmp_path;
my $ram_path;
my $tmp_name;
my $ram_name;
my $adr;
my $rom_adr;
my $ram_adr;
my @rom_buf = (0) x 16384;
my @ram_buf = (0) x 16384;
my @tmp;
my $init;
my @init_table = (0) x 8;
my $module_name;
my $gen_ram = 0;
my $gen_mem = 0;
my $gen_mif = 0;
my $gen_bin = 0;
my $section;
my $timestamp = localtime ();

for my $arg (@ARGV)
{
	if ($arg =~ /^--verilog\s*=\s*(.+).v/)
	{
		$verilog_path = $1;
		print "Verilog path: $1\n";
	}

	if ($arg =~ /^--ram\s*=\s*(.+).sv/)
	{
		$ram_path = $1;
		print "RAM path: $1\n";
	}

	if ($arg =~ /^--gen_ram/)
	{
		$gen_ram = 1;
		print "Generating ram file\n";
	}

	if ($arg =~ /^--gen_mem/)
	{
		$gen_mem = 1;
		print "Generating mem file\n";
	}

	if ($arg =~ /^--gen_mif/)
	{
		$gen_mif = 1;
		print "Generating mif file\n";
	}

	if ($arg =~ /^--gen_bin/)
	{
		$gen_bin = 1;
		print "Generating binary file\n";
	}

}

if (!$verilog_path)
{
	print "No valid Verilog file.\n";
	die;
}

$verilog_file = sprintf("%s.v", $verilog_path);
$ram_file = sprintf("%s.sv", $ram_path);
$mem_rom_file = sprintf("%s_rom.mem", $verilog_path);
$mem_ram_file = sprintf("%s_ram.mem", $verilog_path);
$mif_rom_file = sprintf("%s_rom.mif", $verilog_path);
$mif_ram_file = sprintf("%s_ram.mif", $verilog_path);
$ram_file =~ m/(\w+).sv/;
$bin_rom_file = sprintf("%s_rom.bin", $verilog_path);
$bin_ram_file = sprintf("%s_ram.bin", $verilog_path);
$module_name = $1;
print "Module name : $module_name\n";

read_verilog();

if ($gen_ram)
{
	gen_init_table();
	write_ram();
}

if ($gen_mem)
{
	write_mem();
}

if ($gen_mif)
{
	write_mif();
}

if ($gen_bin)
{
	write_bin();
}


###
# Read verilog input
###
sub read_verilog
{
	open VER, "<$verilog_file" or die "cannot open file: $!";
	print "Reading verilog input\n";

	while ($line = <VER>)
	{
		if ($line =~ /^@([0-9A-F]{8})/)
		{
			print "Address $1\n";
			$adr = hex($1);
			if ($adr == 0) {
				$section = "rom";
				$rom_adr = 0;
			}	else {
				$section = "ram";
				$ram_adr = 0;
			}
		}

		if ($line =~ /^([0-9A-F ]+)/)
		{
			#print "Data $1\n";
			@tmp = split(/ /, $1);
			foreach $tmp (@tmp)
			{
				if ($section eq "rom") {
					$rom_buf[$rom_adr++] = hex($tmp);
				} else {
					$ram_buf[$ram_adr++] = hex($tmp);
				}
			}
		}
	}
	close (VER);
}

###
# Generate INIT table
###
sub gen_init_table
{
	print "Generate init table\n";

	for ($t=0; $t<8; $t++)
	{
		$init_table[$t] = "";

		for ($i=0; $i<64; $i++)
		{
			$init_table[$t] = sprintf("%s\t\t.INIT_%02X(256'h", $init_table[$t], $i);
			for ($j=31; $j>=0; $j--)
			{
				#print "j: $j, buf : $buf[($i*32)+$j])\n";
				$init_table[$t] = sprintf("%s%02X", $init_table[$t], $buf[($t*2048) + ($i*32) + $j]);
			}
			$init_table[$t] = sprintf("%s),\n", $init_table[$t]);
		}
	}

#	print @init_table;
}

###
# Generate memory file
###
sub write_mem
{
	print "Generate memory file\n";

	# ROM
	open MEM, ">$mem_rom_file" or die "cannot open MEM file: $!";
	
	# Time stamp
	printf(MEM "//%s\n", $timestamp);

	# Memory start
	printf(MEM "@%04X\n", 0);

	# Data
	for ($i=0; $i<$rom_adr; $i+=4)
	{
		printf(MEM "%02X%02X%02X%02X\n", $rom_buf[$i+3], $rom_buf[$i+2], $rom_buf[$i+1], $rom_buf[$i]);
	}
	close (MEM);

	# RAM
	open MEM, ">$mem_ram_file" or die "cannot open MEM file: $!";
	
	# Time stamp
	printf(MEM "//%s\n", $timestamp);

	# Memory start
	printf(MEM "@%04X\n", 0);

	# Data
	for ($i=0; $i<$ram_adr; $i+=4)
	{
		printf(MEM "%02X%02X%02X%02X\n", $ram_buf[$i+3], $ram_buf[$i+2], $ram_buf[$i+1], $ram_buf[$i]);
	}
	close (MEM);

}

###
# Generate MIF file
###
sub write_mif
{
	print "Generate mif file\n";

	# ROM
	open MIF, ">$mif_rom_file" or die "cannot open MEM file: $!";

	# Header
	printf(MIF "-----\n");
	printf(MIF "-- MIF ROM %s\n", $module_name);
	printf(MIF "-- %s\n", $timestamp);
	printf(MIF "-----\n");
	printf(MIF "\n");
	printf(MIF "WIDTH=32;\n");
	printf(MIF "DEPTH=%d;\n", $rom_adr/4);
	printf(MIF "ADDRESS_RADIX=HEX;\n");
	printf(MIF "DATA_RADIX=HEX;\n");
	printf(MIF "\n");
	printf(MIF "CONTENT BEGIN\n");

	# Data
	for ($i=0; $i<$rom_adr; $i+=4)
	{
		printf(MIF "\t%04x : %02X%02X%02X%02X;\n", $i/4, $rom_buf[$i+3], $rom_buf[$i+2], $rom_buf[$i+1], $rom_buf[$i]);
	}
	printf(MIF "END;\n");
	close (MIF);

	# RAM
	open MIF, ">$mif_ram_file" or die "cannot open MEM file: $!";

	# Header
	printf(MIF "-----\n");
	printf(MIF "-- MIF RAM %s\n", $module_name);
	printf(MIF "-- %s\n", $timestamp);
	printf(MIF "-----\n");
	printf(MIF "\n");
	printf(MIF "WIDTH=32;\n");
	printf(MIF "DEPTH=%d;\n", $ram_adr/4);
	printf(MIF "ADDRESS_RADIX=HEX;\n");
	printf(MIF "DATA_RADIX=HEX;\n");
	printf(MIF "\n");
	printf(MIF "CONTENT BEGIN\n");

	# Data
	for ($i=0; $i<$ram_adr; $i+=4)
	{
		printf(MIF "\t%04x : %02X%02X%02X%02X;\n", $i/4, $ram_buf[$i+3], $ram_buf[$i+2], $ram_buf[$i+1], $ram_buf[$i]);
	}
	printf(MIF "END;\n");
	close (MIF);
}

###
# Generate binary text file
###
sub write_bin
{
	print "Generate binary text file\n";

	# ROM
	open BIN, ">$bin_rom_file" or die "cannot open BIN file: $!";
	
	# Data
	for ($i=0; $i<$rom_adr; $i+=4)
	{
		printf(BIN "%08b%08b%08b%08b\n", $rom_buf[$i+3], $rom_buf[$i+2], $rom_buf[$i+1], $rom_buf[$i]);
	}
	close (BIN);

	# RAM
	open BIN, ">$bin_ram_file" or die "cannot open BIN file: $!";

	# Data
	for ($i=0; $i<$ram_adr; $i+=4)
	{
		printf(BIN "%08b%08b%08b%08b\n", $ram_buf[$i+3], $ram_buf[$i+2], $ram_buf[$i+1], $ram_buf[$i]);
	}
	close (BIN);
}

print "\n\n";

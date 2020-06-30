#!/usr/bin/env perl

use Getopt::Std;

$opt_r = 1; # report level
$opt_c = 100000; # cycles
$opt_f = 300e6*20; # frequency
$opt_t = 0x1000100000; # threshold

if (!getopts('r:sc:f:t:b:p:') || $#ARGV != 0) {
print <<USAGE;
Usage: tstats.pl -r<int> -s -c<int> -f<fp> -t<hex> -b<ofile> -p<ofile> <trace input file>
  -r  report statistics to STDOUT, level 0..3 (default = 1)
  -s  skip to beginning of capture region (default = false)
  -c  cycles for integration window (default = 100000)
  -f  trace clock frequency (default = 300e6*20)
  -t  threshold address for DRAM, SRAM < (default = 0x1000100000)
  -b  output bandwidth profile (default = none)
  -p  output power profile (default = none)
USAGE
exit(1);
}

open($fhi, "<", $ARGV[0]) or die(" -- error: could not open input $ARGV[0]: $!");

if ($opt_b) {
	open($fhb, ">", $opt_b) or die(" -- error: could not open output $opt_b: $!");
}
if ($opt_p) {
	open($fhp, ">", $opt_p) or die(" -- error: could not open output $opt_p: $!");
}

my $tbeg = 0;
my $tend = $opt_c;
my $period = 1.0/$opt_f;
my $window = $opt_c * $period;

my @master = ("CPU", "LSU", "MCU");
my @tab;
my @btab;
my @etab;

sub output_bandwidth {
	my ($time) = @_;
	while ($time >= $tend) {
		print $fhb $tbeg*$period;
		$tbeg = $tend;
		$tend = $tbeg + $opt_c;
		for my $source (0..2) {
			for my $type ("W", "R") {
				print $fhb " ", $btab[$source]{$type}{BYTES2}/$window;
				$btab[$source]{$type}{BYTES1} = 0;
				$btab[$source]{$type}{BYTES2} = 0;
			}
		}
		print $fhb "\n";
	}
}

sub output_power {
	my ($time) = @_;
	while ($time >= $tend) {
		print $fhp $tbeg*$period, " ",
			$etab[0]{ENERGY1}/$window, " ", ($etab[1]{ENERGY1}+$etab[2]{ENERGY1})/$window, " ",
			$etab[0]{ENERGY2}/$window, " ", ($etab[1]{ENERGY2}+$etab[2]{ENERGY2})/$window, "\n";
		$tbeg = $tend;
		$tend = $tbeg + $opt_c;
		for my $source (0..2) {
			$etab[$source]{ENERGY1} = 0;
			$etab[$source]{ENERGY2} = 0;
		}
	}
}

# skip to beginning of capture region
if ($opt_s) {
	while (<$fhi>) {
		chomp;
		my ($source, $type, $address, $length, $id, $time) = split(',');
		if ($source eq "S" && $address eq "0xAAAAAAAA") {
			print " -- found region start event (0xAAAAAAAA)\n";
			last;
		}
	}
}
while (<$fhi>) {
	chomp;
	my ($source, $type, $address, $length, $id, $time) = split(',');
	$type = uc($type);
	if ($type eq "W" || $type eq "R") {
		my $ram = (hex($address) < $opt_t) ? "SRAM" : "SCM";
		if ($source == 1 && ($id == 2 || $id == 3)) {$source = 2;} # MCU
		my $tref = \%{$tab[$source]{$ram}{$type}};
		my $transport_ebit = ($source == 0) ? 10.0e-12 : 0.0; # Off-chip : On-chip
		my $access_ebit = ($ram eq "SRAM") ? 1.0e-12 : 20.0e-12; # SRAM : SCM
		if ($ram eq "SCM" && $type eq "W") {$access_ebit *= 10;}
		$tref->{ACCESS}++;
		# Narrow access model
		my $transport_bytes1 = $length;
		my $access_bytes1 = $length;
		if ($ram eq "SCM") {
			if ($transport_bytes1 < 8) {$transport_bytes1 = 8;}
			$access_bytes1 = int(($access_bytes1+7)/8) * 8;
		}
		my $energy1 = $transport_ebit * ($transport_bytes1 * 8) + $access_ebit * ($access_bytes1 * 8);
		$tref->{BYTES1} += $transport_bytes1;
		$tref->{ENERGY1} += $energy1;
		# SCM model
		my $transport_bytes2 = $length;
		my $access_bytes2 = $length;
		if ($ram eq "SCM") {
			if ($transport_bytes2 < 16) {$transport_bytes2 = 16;}
			$access_bytes2 = int(($access_bytes2+31)/32) * 32;
		}
		my $energy2 = $transport_ebit * ($transport_bytes2 * 8) + $access_ebit * ($access_bytes2 * 8);
		$tref->{BYTES2} += $transport_bytes2;
		$tref->{ENERGY2} += $energy2;
		# Profiles
		if ($opt_b) {
			output_bandwidth($time); # divide bytes by window size to get bandwidth
			my $btref = \%{$btab[$source]{$type}};
			$btref->{BYTES1} += $transport_bytes1;
			$btref->{BYTES2} += $transport_bytes2;
		}
		if ($opt_p) {
			output_power($time); # divide energy by window size to get power
			my $etref = \%{$etab[$source]};
			$etref->{ENERGY1} += $energy1;
			$etref->{ENERGY2} += $energy2;
		}
	}
}
close($fhi);

if ($opt_r > 0) {
	my $tot_access  = 0;
	my $tot_bytes1  = 0;
	my $tot_energy1 = 0.0;
	my $tot_bytes2  = 0;
	my $tot_energy2 = 0.0;
	print "Path,Access,Bytes(narrow),Joules(narrow),Bytes(SCM),Joules(SCM)", "\n";
	for my $source (0..2) {
		my $mast_access  = 0;
		for my $ram ("SRAM", "SCM") {
			for my $type ("W", "R") {
				$mast_access += $tab[$source]{$ram}{$type}{ACCESS};
			}
		}
		next if $mast_access == 0;
		my $mast_bytes1  = 0;
		my $mast_energy1 = 0.0;
		my $mast_bytes2  = 0;
		my $mast_energy2 = 0.0;
		for my $ram ("SRAM", "SCM") {
			for my $type ("W", "R") {
				my $tref = \%{$tab[$source]{$ram}{$type}};
				print $master[$source], "_", $ram, "_", $type, ",";
				print $tref->{ACCESS}, ",";
				print $tref->{BYTES1}, ",";
				print $tref->{ENERGY1}, ",";
				print $tref->{BYTES2}, ",";
				print $tref->{ENERGY2}, "\n";
				$mast_bytes1  += $tref->{BYTES1};
				$mast_energy1 += $tref->{ENERGY1};
				$mast_bytes2  += $tref->{BYTES2};
				$mast_energy2 += $tref->{ENERGY2};
			}
		}
		print $master[$source], "_Total", ",", $mast_access, ",", $mast_bytes1, ",", $mast_energy1, ",", $mast_bytes2, ",", $mast_energy2, "\n";
		$tot_access  += $mast_access;
		$tot_bytes1  += $mast_bytes1;
		$tot_energy1 += $mast_energy1;
		$tot_bytes2  += $mast_bytes2;
		$tot_energy2 += $mast_energy2;
	}
	print "Total,", $tot_access, ",", $tot_bytes1, ",", $tot_energy1, ",", $tot_bytes2, ",", $tot_energy2, "\n";
}

if ($opt_r > 1) {
	print "\n";
	print "Master,TranW,TranR,ByteW(NAM),ByteR(NAM)", "\n";
	for my $src (0..2) {
		print $master[$src], ",",
			$tab[$src]{"SRAM"}{"W"}{ACCESS} + $tab[$src]{"SCM"}{"W"}{ACCESS}, ",",
			$tab[$src]{"SRAM"}{"R"}{ACCESS} + $tab[$src]{"SCM"}{"R"}{ACCESS}, ",",
			$tab[$src]{"SRAM"}{"W"}{BYTES1} + $tab[$src]{"SCM"}{"W"}{BYTES1}, ",",
			$tab[$src]{"SRAM"}{"R"}{BYTES1} + $tab[$src]{"SCM"}{"R"}{BYTES1}, "\n";
	}
}

if ($opt_r > 2) {
	print "\n";
	print "CPU_SRAM_BytesR/LSU_SRAM_BytesW:", ($tab[1]{"SRAM"}{"W"}{BYTES1} == 0) ? "NA" : $tab[0]{"SRAM"}{"R"}{BYTES1} / $tab[1]{"SRAM"}{"W"}{BYTES1}, "\n";
	print "(LSU_SRAM_BytesR+MCU_SRAM_BytesR)/CPU_SRAM_BytesW:", ($tab[0]{"SRAM"}{"W"}{BYTES1} == 0) ? "NA" : ($tab[1]{"SRAM"}{"R"}{BYTES1}+$tab[2]{"SRAM"}{"R"}{BYTES1}) / $tab[0]{"SRAM"}{"W"}{BYTES1}, "\n";
	print "LSU_SRAM_TranW/LSU_SCM_TranR:",   ($tab[1]{"SCM"}{"R"}{ACCESS} == 0) ? "NA" : $tab[1]{"SRAM"}{"W"}{ACCESS} / $tab[1]{"SCM"}{"R"}{ACCESS}, "\n";
	print "LSU_SRAM_TranR/MCU_SRAM_TranR:",   ($tab[2]{"SRAM"}{"R"}{ACCESS} == 0) ? "NA" : $tab[1]{"SRAM"}{"R"}{ACCESS} / $tab[2]{"SRAM"}{"R"}{ACCESS}, "\n";
}

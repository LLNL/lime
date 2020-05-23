#!/usr/bin/env perl

$opt_a; # annotated trace file name
$opt_l; # average latency file name
$opt_s; # skip to beginning of capture region
$opt_w; # warn if no matching request found
$opt_z; # zynq 7000 32-bit trace
@opt__; # input trace file name

sub usage {
print <<USAGE;
Usage: tlat.pl -a<ofile> -l<ofile> -s -w -z <trace input file>
  -a  output latency annotated trace file (default = none)
  -l  output average latency for each channel (default = none)
  -s  skip to beginning of capture region (default = false)
  -w  warn if no matching request found (default = false)
  -z  zynq 7000 32-bit trace (default = false, zynqmp 64-bit)
USAGE
exit(1);
}

# see perldoc, perlop, I/O Operators 
while ($_ = $ARGV[0]) {
	shift;
	last if /^--$/;
	if (/^-a(.*)/) { $opt_a = $1; next; }
	if (/^-l(.*)/) { $opt_l = $1; next; }
	if (/^-s/)     { $opt_s = 1; next; }
	if (/^-w/)     { $opt_w = 1; next; }
	if (/^-z/)     { $opt_z = 1; next; }
	if (/^[^-]/)   { push @opt__, $_; next; }
	usage();
}
usage() if $#opt__ != 0;
$opt_a = "-" if defined $opt_a && $opt_a eq "";
$opt_l = "-" if defined $opt_l && $opt_l eq "";

# print $opt_a, "\n";
# print $opt_l, "\n";
# print $opt_s, "\n";
# print $opt_w, "\n";
# print $opt_z, "\n";
# foreach (@opt__) { print "$_\n"; }

# open input trace file
open($fhi, "<", $opt__[0]) or die(" -- error: could not open input $opt__[0]: $!");

# open annotated trace file
if ($opt_a) {
	if ($opt_a eq "-") {$fha = \*STDOUT;}
	else {open($fha, ">", $opt_a) or die(" -- error: could not open output $opt_a: $!");}
}

# open average latency trace file
if ($opt_l) {
	if ($opt_l eq "-") {$fhl = \*STDOUT;}
	else {open($fhl, ">", $opt_l) or die(" -- error: could not open output $opt_l: $!");}
}

# setup values depending on platform type (32-bit or 64-bit)
$CPNS = ($opt_z) ? 4 : 6;
$THRESHOLD = ($opt_z) ? 0x40100000 : 0x1000100000;

my @master = ("CPU", "ACC");

my @events;     # outstanding read and write requests
my @req_out;    # outstanding request count
my @req_last;   # last request time stamp
my @histo;      # histogram of latency
# my @req_access; # access count
# my @req_bytes;  # byte count

# Column : Description
#      0 : Trace event source
#      1 : Event type
#      2 : Address in HEX with 0x prefix
#      3 : Length in bytes
#      4 : AXI bus ID
#      5 : Time stamp count
#--------
#      6 : Outstanding request count (on same channel source:type:id)
#      7 : Clocks since last request (on same channel source:type:id)
#      8 : Latency
#      9 : Temporary variable to flag FW has been received

# TODO:
# Track latency of W -> FW?
# Make tracking of latency FW/LW -> B an option (-f).
# Find more deterministic way to synchronize start of trace

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
	if ($type eq "W" || $type eq "R") { # open event
		$req_out[$source]{$type}{$id}++;
		push @events, [$source, $type, $address, $length, $id, $time,
			$req_out[$source]{$type}{$id},
			$time-$req_last[$source]{$type}{$id}];
		$req_last[$source]{$type}{$id} = $time;
		# my $ram = (hex($address) < $THRESHOLD) ? "SRAM" : "DRAM";
		# $req_access[$source]{$ram}{$type}++;
		# $req_bytes[$source]{$ram}{$type} += $length;
	} elsif ($type eq "FW" || $type eq "DW") { # Track latency of FW -> B
		my $found = 0;
		my $req = "W";
		for my $aref (@events) {
			if (!defined $aref->[8] &&
				!defined $aref->[9] &&
				$aref->[0] == $source &&
				$aref->[1] eq $req)
			{
				$aref->[5] = $time;
				$aref->[9] = 1;
				$found = 1;
				last;
			}
		}
		if (!$found) {
			print " -- no request found for ",
				join(',',$source, $type, $address, $length, $id, $time), "\n"
				if $opt_w;
			next;
		}
	} elsif ($type eq "B" || $type eq "LR" || $type eq "DR") { # close event
		my $found = 0;
		my $req = ($type eq "B") ? "W" : "R";
		for my $aref (@events) {
			if (!defined $aref->[8] &&
				$aref->[0] == $source &&
				$aref->[1] eq $req &&
				$aref->[4] == $id)
			{
				my $latency = $time - $aref->[5];
				my $ram = (hex($aref->[2]) < $THRESHOLD) ? "SRAM" : "DRAM";
				$found = 1;
				$aref->[8] = $latency;
				$req_out[$source]{$req}{$id}--;
				$histo[$source]{$ram}{$req}[$latency]++;
				if ($#{$aref} > 8) {delete $aref->[9];}
				last;
			}
		}
		if (!$found) {
			print " -- no request found for ",
				join(',',$source, $type, $address, $length, $id, $time), "\n"
				if $opt_w;
			next;
		}
		while ($#events >= 0 && defined $events[0][8]) {
			my $aref = shift @events;
			print $fha join(',', @$aref), "\n" if $opt_a;
		}
	}
	if ($#events >= 2048) { # flush if too many events
		my $aref = shift @events;
		print $fha join(',', @$aref), "\n" if $opt_a;
	}
}
close($fhi);

if ($opt_a) { # flush remaining events
	for my $aref (@events) {
		print $fha join(',', @$aref), "\n";
	}
	close($fha) if $opt_a ne "-";
}

if ($opt_l) {
	printf $fhl "# Latency in ns for %s\n", $opt__[0];
	print  $fhl "#  Channel,    Avg,     Lo,     Hi\n";
	for my $source (0..1) {
		for my $ram ("SRAM", "DRAM") {
			for my $type ("W", "R") {
				my $lref = \@{$histo[$source]{$ram}{$type}};
				my $tot_cnt = 0;
				my $tot_lat = 0;
				my $min = 0;
				for my $i (1..$#{$lref}) {
					$tot_cnt += $lref->[$i];
					$tot_lat += $lref->[$i] * $i;
					$min = $i if !$min && $lref->[$i];
				}
				next if $tot_cnt == 0;
				my $avg = $tot_lat/$tot_cnt/$CPNS;
				my $lo = $min/$CPNS;
				my $hi = $#{$lref}/$CPNS;
				my $flag = ($lo < 0.5*$avg || $hi > 2*$avg) ? " *" : "";
				printf $fhl "%s_%s_%s, %6.2f, %6.2f, %6.2f%s\n",
					$master[$source], $ram, $type, $avg, $lo, $hi, $flag;
			}
		}
	}
	close($fhl) if $opt_l ne "-";
}

#!/usr/bin/env perl

@opt_l; # labels and address ranges
$opt_o; # output trace file name
$opt_s; # skip to beginning of capture region
@opt__; # input trace file name

sub usage {
print <<USAGE;
Usage: tlabel.pl -l<label,address,size> -o<ofile> -s <trace input file>
  -l  label and address range (default = none)
  -o  output trace file name (default = none)
  -s  skip to beginning of capture region (default = false)
USAGE
exit(1);
}

# see perldoc, perlop, I/O Operators 
while ($_ = $ARGV[0]) {
	shift;
	last if /^--$/;
	if (/^-l(.*)/) { push @opt_l, [split(',',$1)]; next; }
	if (/^-o(.*)/) { $opt_o = $1; next; }
	if (/^-s/)     { $opt_s = 1; next; }
	if (/^[^-]/)   { push @opt__, $_; next; }
	usage();
}
usage() if $#opt__ != 0;
$opt_o = "-" if defined $opt_o && $opt_o eq "";

# foreach (@opt_l) { print "$_->[0] $_->[1] $_->[2]\n"; }
# print $opt_o, "\n";
# print $opt_s, "\n";
# foreach (@opt__) { print "$_\n"; }

# open input trace file
open($fhi, "<", $opt__[0]) or die(" -- error: could not open input $opt__[0]: $!");

# open output trace file
if ($opt_o) {
	if ($opt_o eq "-") {$fho = \*STDOUT;}
	else {open($fho, ">", $opt_o) or die(" -- error: could not open output $opt_o: $!");}
}

# Column : Description
#      0 : Trace event source
#      1 : Event type
#      2 : Address in HEX with 0x prefix
#      3 : Length in bytes
#      4 : AXI bus ID
#      5 : Time stamp count
#--------
#      6 : Label

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
	my @event = split(',');
	my $label = "";
	my $type = uc($event[1]);
	if ($type eq "W" || $type eq "R") { # write or read event
		my $address = hex($event[2]);
		foreach (@opt_l) {
			if ($address >= hex($_->[1]) && $address < hex($_->[1])+hex($_->[2])) {
				$label = $_->[0];
				last;
			}
		}
	}
	print $fho join(',' ,@event), ($label) ? " #$label" : "", "\n" if $opt_o;
}
close($fhi);

if ($opt_o) {
	close($fho) if $opt_o ne "-";
}

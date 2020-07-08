#!/bin/bash
# Description: plot a histogram of the latency from a trace file
#

usage() {
	echo "Usage: lplot.sh -a -b<str> -f -s -z <input> [subtitle]" 1>&2
	echo "  -a: show accelerator masters" 1>&2
	echo "  -b: base file name for output" 1>&2
	echo "  -f: force update of intermediate files" 1>&2
	echo "  -s: skip to beginning of capture region" 1>&2
	echo "  -z: zynq 7000 32-bit trace" 1>&2
	echo "  input (file): trace.csv" 1>&2
	echo "  subtitle (str): append to title on graph" 1>&2
	exit 1
}

opt_a=0
opt_b=""
opt_f=0
opt_s=0
opt_z=0
while getopts ":ab:fsz" opt; do
	case $opt in
	a) opt_a=1;;
	b) opt_b=$OPTARG;;
	f) opt_f=1;;
	s) opt_s=1;;
	z) opt_z=1;;
	*) usage;;
	esac
done
shift $((OPTIND-1))
if [ $# -lt 1 ]; then usage; fi

fname=${1##*/}    # filename, no directory path
fbase=${fname%.*} # filename, no extension
subtitle=$2       # append to title on graph
tools=$(dirname "${BASH_SOURCE[0]}")

if (($opt_a)); then ch=10; else ch=2; fi
if [ -n "$opt_b" ]; then fbase=$opt_b; fi
if (($opt_s)); then ss=-s; fi
# 20x the PL 1 clock frequency
if (($opt_z)); then fr="4e9"; zz=-z; else fr="6e9"; fi
#if (($opt_z)); then fr="4e9"; zz=-z; else fr="3.749625e9"; fi

# Create latency annotated .csv file and latency summary .csv file.
fann=${fbase}_a.csv
fsum=${fbase}_s.csv
if [ "$1" -nt "$fann" -o $opt_f -eq 1 ]; then
  perl $tools/tlat.pl $ss $zz -a$fann -l$fsum $1
fi

# Create .dat file for gnuplot.
fout=${fbase}_l
fdat=${fout}.dat
if [ "$fann" -nt "$fdat" -o $opt_f -eq 1 ]; then
  awk -v chans=$ch -v freq=$fr -f $tools/latency.awk $fann > $fdat
fi

# Create .plt file for gnuplot.
fplt=${fout}.plt
echo "set title \"Latency$subtitle\"" > $fplt
#echo 'set key left top' >> $fplt
echo 'set style data histeps' >> $fplt
echo 'set xlabel "Number of Clock Cycles"' >> $fplt
# echo 'set xlabel "Time in Nanoseconds"' >> $fplt
echo 'set ylabel "Number of Transactions"' >> $fplt
echo "set yrange [0:]" >> $fplt
echo "set xrange [0:]" >> $fplt
# echo "set xtics 20" >> $fplt
echo 'set terminal png size 1024,768' >> $fplt
echo "set output '${fout}.png'" >> $fplt
if (($opt_a)); then
echo "plot \\" >> $fplt
echo "  \"$fdat\" using 1:2 title 'CPU Read', \\" >> $fplt
echo "  \"$fdat\" using 1:3 title 'CPU Write', \\" >> $fplt
echo "  \"$fdat\" using 1:4 title 'LSU Read', \\" >> $fplt
echo "  \"$fdat\" using 1:5 title 'LSU Write', \\" >> $fplt
echo "  \"$fdat\" using 1:6 title 'MCU Read', \\" >> $fplt
echo "  \"$fdat\" using 1:7 title 'MCU Write', \\" >> $fplt
echo "  \"$fdat\" using 1:8 title 'LSU1 Read', \\" >> $fplt
echo "  \"$fdat\" using 1:9 title 'LSU1 Write', \\" >> $fplt
echo "  \"$fdat\" using 1:10 title 'LSU2 Read', \\" >> $fplt
echo "  \"$fdat\" using 1:11 title 'LSU2 Write'" >> $fplt
else
echo "plot \\" >> $fplt
echo "  \"$fdat\" using 1:2 title 'CPU Read', \\" >> $fplt
echo "  \"$fdat\" using 1:3 title 'CPU Write'" >> $fplt
fi
# echo 'set terminal pdf size 4in,3in' >> $fplt
# echo "set output '${fout}.pdf'" >> $fplt
# echo 'replot' >> $fplt
gnuplot $fplt
rm $fplt

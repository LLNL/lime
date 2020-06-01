BEGIN {
	FS = ","
	if (freq == 0) freq = 300e6*20
	if (cycles == 0) cycles = 100000
	if (thresh == 0) thresh = 0x1000100000
	tbeg = 0
	tend = cycles
	period = 1.0/freq
	window = cycles * period
	OUT_STATS = "/dev/stderr"
	# HMC energy model - energy per bit
	DRAM_epb = 19.4e-12
	SRAM_epb =  1.0e-12
	OFFC_epb = 10.3e-12
}

function output(time) {
	while (time >= tend) {
		arm_et += arm_ep
		dre_et += dre_ep
		print tbeg*period, arm_ep/window, dre_ep/window
		tbeg = tend
		tend = tbeg + cycles
		arm_ep = 0
		dre_ep = 0
	}
}

function tmps() {
	tmp_l = $4
	if (strtonum($3) < thresh) {
		# SRAM
		tmp_e = SRAM_epb
	} else {
		# DRAM
		tmp_e = DRAM_epb
		if ($2 == "W" && tmp_l < 8) {tmp_l = 8}
		else if ($2 == "R" && tmp_l < 16) {tmp_l = 16}
	}
}

$1 == 0 {
	output($6)
	if ($2 == "R" || $2 == "W") {
		tmps()
		tmp_e += OFFC_epb
	}
	if ($2 == "R") {
		arm_ra++
		arm_rb += tmp_l
		arm_ep += tmp_l * 8 * tmp_e
	}
	if ($2 == "W") {
		arm_wa++
		arm_wb += tmp_l
		arm_ep += tmp_l * 8 * tmp_e
	}
}

$1 == 1 {
	output($6)
	if ($2 == "R" || $2 == "W") {
		tmps()
	}
	if ($2 == "R") {
		dre_ra++
		dre_rb += tmp_l
		dre_ep += tmp_l * 8 * tmp_e
	}
	if ($2 == "W") {
		dre_wa++
		dre_wb += tmp_l
		dre_ep += tmp_l * 8 * tmp_e
	}
}

END {
	output(tend)
	print FILENAME > OUT_STATS
	print "Window (s):", window > OUT_STATS
	print "Access ARM read:", arm_ra, "ARM write:", arm_wa > OUT_STATS
	if (dre_ra != 0 || dre_wa != 0) {
		print "Access DRE read:", dre_ra, "DRE write:", dre_wa > OUT_STATS
	}
	print "Bytes  ARM read:", arm_rb, "ARM write:", arm_wb > OUT_STATS
	if (dre_rb != 0 || dre_wb != 0) {
		print "Bytes  DRE read:", dre_rb, "DRE write:", dre_wb > OUT_STATS
	}
	print "Joules ARM:", arm_et > OUT_STATS
	if (dre_et != 0) {
		print "Joules DRE:", dre_et > OUT_STATS
		print "Joules A+D:", arm_et+dre_et > OUT_STATS
	}
}

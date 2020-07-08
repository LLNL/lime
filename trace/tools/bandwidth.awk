BEGIN {
	FS = ","
	if (freq == 0) freq = 249.98e6*20
#	if (freq == 0) freq = 187.48125e6*20
	if (chans == 0) chans = 10
	if (cycles == 0) cycles = 100000
	tbeg = 0
	tend = cycles
	period = 1.0/freq
	window = cycles * period
	OUT_STATS = "/dev/stderr"
	cname[0] = "CPU_Read"
	cname[1] = "CPU_Write"
	cname[2] = "LSU_Read"
	cname[3] = "LSU_Write"
	cname[4] = "MCU_Read"
	cname[5] = "MCU_Write"
	cname[6] = "LSU1_Read"
	cname[7] = "LSU1_Write"
	cname[8] = "LSU2_Read"
	cname[9] = "LSU2_Write"
	for (i = 0; i < chans; i++) {
		caccess[i] = 0
		cbytes[i] = 0
	}
}

function output(time) {
	while (time >= tend) {
		printf "%g", tbeg*period
		for (i = 0; i < chans; i++) printf " %g", cbytesp[i]/window
		printf "\n"
		for (i = 0; i < chans; i++) cbytesp[i] = 0
		tbeg = tend
		tend = tbeg + cycles
	}
}

function update() {
	tmp_l = $4
	caccess[ch]++
	cbytes[ch] += tmp_l
	cbytesp[ch] += tmp_l
}

$1 == 0 {
	output($6)
	# CPU
	if ($2 == "R") ch = 0
	if ($2 == "W") ch = 1
	update()
}

$1 == 1 {
	output($6)
	# Accelerator
	ch = strtonum($5) + 2
	update()
}

END {
	output(tend)
	print FILENAME > OUT_STATS
	print "Window (s):", window > OUT_STATS
	OFS = ","
	print "Path", "Access", "Bytes" > OUT_STATS
	for (i = 0; i < chans; i++) {
		print cname[i], caccess[i], cbytes[i] > OUT_STATS
	}
}

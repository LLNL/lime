BEGIN {
	FS = ","
<<<<<<< HEAD
	if (freq == 0) freq = 187.48125e6*20
=======
	if (freq == 0) freq = 300e6*20
>>>>>>> master
	if (chans == 0) chans = 10
	cname[0] = "CPU_Read"
	cname[1] = "CPU_Write"
	cname[2] = "LSU0_Read"
	cname[3] = "LSU0_Write"
	cname[4] = "MCU_Read"
	cname[5] = "MCU_Write"
	cname[6] = "LSU1_Read"
	cname[7] = "LSU1_Write"
	cname[8] = "LSU2_Read"
	cname[9] = "LSU2_Write"
	clo = 4294967295
	chi = 0
}

function update() {
#	if (strtonum($3) < thresh) {
#		# SRAM
#	} else {
#		# DRAM
#	}
	# latency in nano seconds
	latency = int($9/freq*1e9)
	if (latency < clo) clo = latency
	if (latency > chi) chi = latency
	clat[ch][latency]++
}

$1 == 0 {
	# CPU
	if ($2 == "R") ch = 0
	if ($2 == "W") ch = 1
	update()
}

$1 == 1 {
	# Accelerator
	ch = strtonum($5) + 2
	update()
}

END {
	printf "# Latency"
	for (i = 0; i < chans; i++) printf " %s", cname[i]
	printf "\n"
	for (j = clo; j <= chi; j++) {
		printf " %d", j
		for (i = 0; i < chans; i++) printf " %d", clat[i][j]
		printf "\n"
	}
}

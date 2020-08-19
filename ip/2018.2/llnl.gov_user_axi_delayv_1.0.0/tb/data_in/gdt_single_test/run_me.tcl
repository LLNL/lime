for {set i 0} {$i < 15} {incr i} {
    run 20us
    add_force {/channel_delay_tb/axi_slave_inst/s_axi_ready_o} -radix bin {"0" 0ns} -cancel_after 5000ns
}
run 1us

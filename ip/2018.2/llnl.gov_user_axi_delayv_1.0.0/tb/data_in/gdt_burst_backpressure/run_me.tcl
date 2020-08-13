for {set i 0} {$i < 160} {incr i} {
    run 2.5us
    add_force {/channel_delay_tb/axi_slave_inst/s_axi_ready_o} -radix bin {"0" 0ns} -cancel_after 1511ns
}
run 10us
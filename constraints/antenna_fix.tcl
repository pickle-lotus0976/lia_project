# Force diode placement on critical nets
set critical_nets [list net268 _0072_ net716 mixer_i.valid_stage2 net311 mixer_q.product\[17\]]
foreach net $critical_nets {
    insert_diode -net $net -layer met5
}

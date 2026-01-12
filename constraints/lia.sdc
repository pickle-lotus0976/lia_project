# Clock definition
create_clock -name clk -period 20.0 [get_ports clk]

# Input delays
set_input_delay -clock clk -max 2.0 [get_ports {adc_data[*] adc_valid phase_increment[*]}]
set_input_delay -clock clk -min 0.5 [get_ports {adc_data[*] adc_valid phase_increment[*]}]

# Output delays
set_output_delay -clock clk -max 2.0 [get_ports {mixer_i_out[*] mixer_q_out[*] mixer_valid}]
set_output_delay -clock clk -min -0.5 [get_ports {mixer_i_out[*] mixer_q_out[*] mixer_valid}]

# Clock uncertainty
set_clock_uncertainty 0.5 [get_clocks clk]

# Clock transition
set_clock_transition 0.2 [get_clocks clk]

# Input transition
set_input_transition 0.5 [all_inputs]

# Load capacitance - CHANGE THIS LINE ONLY
set_load 0.10 [all_outputs]

# Max fanout
set_max_fanout 8 [current_design]

# Max transition
set_max_transition 1.0 [current_design]

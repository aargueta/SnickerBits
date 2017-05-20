set_operating_conditions -grade commercial
set_operating_conditions -heatsink low
set_switching_activity -deassert_resets 
#create_clock -period 5.000 -name clk_axi -waveform {0.000 2.500}
set_switching_activity -deassert_resets 
create_clock -period 6.667 -name clk_axi [get_pins clk_axi_IBUF_inst/O]

set_switching_activity -deassert_resets 

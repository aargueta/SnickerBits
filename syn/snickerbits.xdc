set_operating_conditions -grade commercial
set_operating_conditions -heatsink low
set_switching_activity -deassert_resets 
create_clock -period 5.000 -name clk_axi -waveform {0.000 2.500}
set_switching_activity -deassert_resets 

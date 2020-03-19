create_clock -name clk_50k -period 20000 [get_registers {Clk50K:iClk50K|clk_50K}]
create_clock -name clk_50m -period 20.000 [get_ports {clk_50M}]
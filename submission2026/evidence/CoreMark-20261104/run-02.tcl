cfg_set_tcl_break -flag true
cfg_connect -ip 127.0.0.1 -port 65420
cfg_scan_chain
cfg_assign_file -file {C:/Users/33791/Desktop/project/learn verilog/final2/output/bitstream/cpu_only_90MHz_verified.sbit} -device_index 0
cfg_program -device_index 0
cfg_read_device_property -device_index 0 -mode 3
exit

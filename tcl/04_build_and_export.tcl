# Synthesis, implementation, and export
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
write_hw_platform -fixed -include_bit -force IMAGE_15EG_wrapper.xsa
puts "Build complete! The hardware platform has been exported to IMAGE_15EG_wrapper.xsa."

# Generate wrapper and add to project
make_wrapper -files [get_files ./IMAGE_15EG_TCL/IMAGE_15EG_TCL.srcs/sources_1/bd/IMAGE_15EG/IMAGE_15EG.bd] -top
add_files -norecurse ./IMAGE_15EG_TCL/IMAGE_15EG_TCL.gen/sources_1/bd/IMAGE_15EG/hdl/IMAGE_15EG_wrapper.v
set_property top IMAGE_15EG_wrapper [current_fileset]
update_compile_order -fileset sources_1

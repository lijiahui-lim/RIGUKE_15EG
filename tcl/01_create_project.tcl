# Vivado project creation
create_project -force IMAGE_15EG_TCL ./IMAGE_15EG_TCL -part xczu15eg-ffvb1156-2-i
add_files -fileset constrs_1 -norecurse ./src/constrs/IMAGE_15EG.xdc

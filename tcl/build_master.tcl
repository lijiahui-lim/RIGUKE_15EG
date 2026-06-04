# Master build script for IMAGE_15EG
set script_dir [file dirname [info script]]
source ${script_dir}/01_create_project.tcl
source ${script_dir}/02_create_bd.tcl
source ${script_dir}/03_make_wrapper.tcl
source ${script_dir}/04_build_and_export.tcl

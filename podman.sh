#!/bin/bash
#--network=pasta \   
podman run -it --rm \
  --userns=keep-id:uid=1000,gid=1000 \
  --user vivado \
  --name petalinux_2022_run \
  --network=pasta \
  -p 69:69/udp \
  -v $(pwd):/workspace \
  -w /workspace \
  localhost/ubuntu_petalinux_rk3588:v3 \
  /bin/bash

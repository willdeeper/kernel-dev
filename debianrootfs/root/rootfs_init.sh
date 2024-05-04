#!/usr/bin/env bash
# setup in rootfs

PASSWD=123456

echo -e "$PASSWD\n$PASSWD\n" | passwd root

apt update
apt install wget curl libbpf-dev libelf-dev libssl-dev build-essential clang git bpftool \
    linux-perf pkg-config tcpdump llvm automake m4 autoconf libpcap-dev openssh-server \
    libc6-dev-i386 libxdp-dev vim apt-file sudo locales tmux -y
apt-file update
# rust
curl https://sh.rustup.rs -sSf | sh -s -- -y --no-modify-path
chsh -s /bin/bash

# add path env
cat << EOF >> ~/.bashrc
export PATH=$PATH:~/.cargo/bin
EOF
source ~/.bashrc
cargo install bpf-linker

exit
#!/usr/bin/env bash

# setup in rootfs
echo -e "$PASSWD\n$PASSWD\n" | passwd root
exit
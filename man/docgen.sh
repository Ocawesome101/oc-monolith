#!/bin/bash
# Automated manual page generation in lieu of a Makefile

set -x
set -e

for file in $(find man -type f); do
  ./docgen.lua $file ../build/usr/$file
done

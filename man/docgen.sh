#!/bin/bash
# Automated manual page generation in lieu of a proper Makefile

printf "\033[39m[ \033[94mINFO\033[39m ] Generating man-page documentation....\n"
set -e

for file in $(find man -type f); do
  ./docgen.lua $file ../build/usr/$file
done

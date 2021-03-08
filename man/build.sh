#!/bin/bash
# ok bois here we go

set -e

log () {
  printf "[ $1\033[39m ] $2\n"
}

./docgen.sh

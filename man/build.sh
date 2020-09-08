#!/bin/bash
# ok bois here we go

set -e

log () {
  /bin/echo -e "[ $1\033[39m ] $2"
}

./docgen.sh

#!/bin/bash
#
# Build this whole frickin' thing

set -e

export OK="\033[39m[ \033[92m OK \033[39m ]"
export INFO="\033[39m[ \033[94mINFO\033[39m ]"
export FAIL="\033[39m[ \033[91mFAIL\033[39m ]"
export WAIT="\033[39m[ \033[93mWAIT\033[39m ]"
export luacomp="$PWD/luacomp"

log() {
  /bin/echo -e "\e[G$@"
}

build() {
  cd $1
  ./build.sh
  cd ..
}

rm -rf build
log "$INFO Building Monolith"
mkdir -p build/{usr/man,sbin}
cp -r util/* build
log "$OK Built utilities"
build man
log "$OK Generated manual pages"
build kernel
log "$INFO Copying kernel to build" 
cp kernel/monolith build/boot/
build init
log "$INFO Copying init to build"
cp init/init.lua build/sbin

while [ $# -gt 0 ]; do
  case "$1" in
    release)
      log "$WAIT Building release.cpio"
      cd build && find ./* | cpio -o > ../release.cpio && cd ..
      printf "\e[2A\e[G$OK\e[2B"
      log "$WAIT Building packages/base.cpio"
      cp package.cfg build
      rm -rf build/etc/ build/home
      cd build && find ./* | cpio -o > ../packages/base.cpio && cd ..
      printf "\e[2A\e[G$OK\e[2B"
      cp -r util/etc build/etc
      shift
      ;;
    webdoc)
      log "$WAIT Assembling man pages in web format"
      cd man
      ./genhtml.sh
      cd web
      push-man
      cd ..
      shift
      ;;
    *)
      shift
      ;;
  esac
done

log "$INFO Done."

unset WAIT
unset FAIL
unset INFO
unset OK

#!/bin/bash
#
# build init

printf "$INFO Building the InitMe init system\n"
$luacomp base.lua -Oinit.lua
printf "$OK Built InitMe\n"

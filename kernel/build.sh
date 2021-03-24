#!/bin/bash
#
# Build me

printf "$INFO Beginning kernel build\n"
$luacomp base.lua -Omonolith
printf "$OK Built kernel\n"

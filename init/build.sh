#!/bin/bash
#
# build init

/bin/echo -e "$INFO Building the InitMe init system"
$luacomp base.lua -Oinit.lua
/bin/echo -e "$OK Built InitMe"

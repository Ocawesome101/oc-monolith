#!/bin/bash
#
# Build me

/bin/echo -e "$INFO Beginning kernel build"
$luacomp base.lua -Omonolith
/bin/echo -e "$OK Built kernel"

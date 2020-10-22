#!/bin/bash
# Automated manual page generation in lieu of a proper Makefile

/bin/echo -e "\033[39m[ \033[94mINFO\033[39m ] Generating markdown man-page documentation...."
set -e
mkdir -p ./web/man
DOMAIN='oz-craft.pickardayune.com'

echo '
<link rel="stylesheet" href="https://oz-craft.pickardayune.com/blog/style.css">
<html><title>Monolith manual pages</title>
<body>
<p>
The following links point to all currently available manual pages from the Monolith system.<br><br>If you notice any deficiencies, please open an issue on the <a href="https://github.com/ocawesome101/oc-monolith/issues">Monolith GitHub Issues page</a>.
</p>
' > ./web/man/index.html

for file in $(find man -type f | sort); do
  mkdir -p ./web/$file/
  ./genhtml.lua $file ./web/$file/index.html
  echo '<a href="https://'$DOMAIN'/'$file'">'$file'</a><br>' >> ./web/man/index.html
done

echo '</body></html>' >> ./web/man/index.html

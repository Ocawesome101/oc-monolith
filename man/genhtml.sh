#!/bin/bash
# Automated manual page generation in lieu of a proper Makefile

/bin/echo -e "\033[39m[ \033[94mINFO\033[39m ] Generating markdown man-page documentation...."
set -e
DOMAIN='oz-craft.pickardayune.com'

echo '
<html><title>Monolith manual pages</title>
<body>
<p>
The following links point to all currently available manual pages from the Monolith system.
</p>
' > ./web/man/index.html

for file in $(find man -type f); do
  mkdir -p ./web/$file/
  ./genhtml.lua $file ./web/$file/index.html
  echo '<a href="https://'$DOMAIN'/'$file'">'$file'</a><br>' >> ./web/man/index.html
done

echo '</body></html>' >> ./web/man/index.html

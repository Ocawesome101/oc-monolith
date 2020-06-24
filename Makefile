# Build this whole frickin' thing

KERNEL = "monolith"

all:
	rm -rf build
	mkdir -p build/{usr/man,sbin}
	cp -r util/* build
	$(MAKE) -C kernel
	cp kernel/$(KERNEL) build/boot/
	$(MAKE) -C init
	cp init/init.lua build/sbin
	rm -f build/Makefile build/DOCS.md
	$(MAKE) -C man

release: all
	cd build && find ./* | cpio -o > ../release.cpio && cd ..
#	lua5.3 lzssit.lua

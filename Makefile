# Build this whole frickin' thing

all:
	rm -rf build
	mkdir -p build/{usr/man,boot,sbin}
	$(MAKE) -C kernel
	cp kernel/kernel.lua build/boot/
	$(MAKE) -C init
	cp init/init.lua build/sbin
	$(MAKE) -C util
	cp -r util/* build
	rm -f build/Makefile build/DOCS.md
	$(MAKE) -C man

release: all
	cd build && find ./* | cpio -o > ../release.cpio && cd ..
#	lua5.3 lzssit.lua

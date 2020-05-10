# Build this whole frickin' thing

all:
	rm -rf build
	mkdir -p build/sbin build/boot
	$(MAKE) -C kernel
	cp kernel/kernel.lua build/boot/
	$(MAKE) -C init
	cp init/init.lua build/sbin
	$(MAKE) -C util
	cp -r util/* build
	rm -f build/Makefile

release: all
	find build | cpio -o > release.cpio

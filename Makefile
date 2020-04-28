# Build this whole frickin' thing

all:
	rm -rf build
	mkdir -p build/sbin
	$(MAKE) -C kernel
	cp kernel/kernel.lua build
	$(MAKE) -C init
	cp init/init.lua build/sbin
	$(MAKE) -C util
	cp -r util/* build
	build/bin/mkinitfs.lua --root build

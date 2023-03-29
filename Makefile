kernel_source_files := $(shell find src/impl/kernel -name *.c)
kernel_object_files := $(patsubst src/impl/kernel/%.c, build/kernel/%.o, $(kernel_source_files))

x86_64_c_source_files := $(shell find src/impl/x86_64 -name *.c)
x86_64_c_object_files := $(patsubst src/impl/x86_64/%.c, build/x86_64/%.o, $(x86_64_c_source_files))

x86_64_asm_source_files := $(shell find src/impl/x86_64 -name *.asm)
x86_64_asm_object_files := $(patsubst src/impl/x86_64/%.asm, build/x86_64/%.o, $(x86_64_asm_source_files))

x86_64_object_files := $(x86_64_c_object_files) $(x86_64_asm_object_files)

target = x86_64-elf
toolchain_prefix = $(abspath /usr)

$(kernel_object_files): build/kernel/%.o : src/impl/kernel/%.c
	mkdir -p $(dir $@) && \
	x86_64-elf-gcc -c -I src/intf -ffreestanding $(patsubst build/kernel/%.o, src/impl/kernel/%.c, $@) -o $@

$(x86_64_c_object_files): build/x86_64/%.o : src/impl/x86_64/%.c
	mkdir -p $(dir $@) && \
	x86_64-elf-gcc -c -I src/intf -ffreestanding $(patsubst build/x86_64/%.o, src/impl/x86_64/%.c, $@) -o $@

$(x86_64_asm_object_files): build/x86_64/%.o : src/impl/x86_64/%.asm
	mkdir -p $(dir $@) && \
	nasm -f elf64 $(patsubst build/x86_64/%.o, src/impl/x86_64/%.asm, $@) -o $@

.PHONY: build-x86_64 toolchain clean clean-toolchain-all clean-toolchain toolchain_binutils toolchain_gcc
build-x86_64: toolchain $(kernel_object_files) $(x86_64_object_files)
	mkdir -p dist/x86_64 && \
	x86_64-elf-ld -n -o dist/x86_64/kernel.bin -T targets/x86_64/linker.ld $(kernel_object_files) $(x86_64_object_files) && \
	cp dist/x86_64/kernel.bin targets/x86_64/iso/boot/kernel.bin && \
	grub-mkrescue /usr/lib/grub/i386-pc -o dist/x86_64/kernel.iso targets/x86_64/iso

toolchain: toolchain_binutils toolchain_gcc

binutils_version = 2.40
binutils_src = toolchain/binutils-$(binutils_version)
binutils_build = toolchain/binutils-build-$(binutils_version)

toolchain_binutils: $(toolchain_prefix)/bin/x86_64-elf-ld

$(toolchain_prefix)/bin/x86_64-elf-ld: $(binutils_src).tar.xz
	mkdir -p $(binutils_build)
	cd $(binutils_build) && CFLAGS= ASMFLAGS= CC= CXX= LD= ASM= LINKFLAGS= LIBS= ../binutils-$(binutils_version)/configure \
			--prefix="$(toolchain_prefix)" \
			--target=$(target) \
			--with-sysroot \
			--disable-nls \
			--disable-werror
	$(MAKE) -j8 -C $(binutils_build)
	$(MAKE) -C $(binutils_build) install

$(binutils_src).tar.xz:
	mkdir -p toolchain
	cd toolchain && wget https://ftp.gnu.org/gnu/binutils/binutils-$(binutils_version).tar.xz
	cd toolchain && tar xf binutils-$(binutils_version).tar.xz

gcc_version = 12.2.0
gcc_src = toolchain/gcc-$(gcc_version)
gcc_build = toolchain/gcc-build-$(gcc_version)

toolchain_gcc: $(toolchain_prefix)/bin/x86_64-elf-gcc

$(toolchain_prefix)/bin/x86_64-elf-gcc: $(gcc_src).tar.xz
	mkdir -p $(gcc_build)
	cd $(gcc_build) && CFLAGS= ASMFLAGS= CC= CXX= LD= ASM= LINKFLAGS= LIBS= ../gcc-$(gcc_version)/configure \
			--prefix="$(toolchain_prefix)" \
			--target=$(target) \
			--disable-nls \
			--enable-languages=c,c++ \
			--without-headers
	$(MAKE) -j8 -C $(gcc_build) all-gcc all-target-libgcc
	$(MAKE) -C $(gcc_build) install-gcc install-target-libgcc

$(gcc_src).tar.xz:
	mkdir -p toolchain
	cd toolchain && wget https://ftp.gnu.org/gnu/gcc/gcc-$(gcc_version)/gcc-$(gcc_version).tar.xz
	cd toolchain && tar xf gcc-$(gcc_version).tar.xz

clean:
	rm -rf build
	rm -rf dist
	rm -f targets/x86_64/iso/boot/kernel.bin

clean-toolchain:
	rm -rf $(binutils_src) $(binutils_build) $(gcc_src) $(gcc_build)

clean-toolchain-all:
	rm -rf toolchain

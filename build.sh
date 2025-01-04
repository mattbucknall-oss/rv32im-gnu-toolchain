#/bin/env bash

# exit on errors
set -e

# show progress
set -x

# toolchain properties
export TARGET=riscv32-unknown-elf
export NAME=gcc-$TARGET
export PREFIX=$PWD/build-root
export PATH=$PREFIX/bin:$PATH
export ARCH=rv32im

# create build directories
mkdir -p build/binutils
mkdir -p build/gcc
mkdir -p build/newlib
mkdir -p build/gdb

# extract sources
tar -xf packages/binutils-*.tar.* -C build/binutils --strip-components=1 &
tar -xf packages/gcc-*.tar.* -C build/gcc --strip-components=1 &
tar -xf packages/newlib-*.tar.* -C build/newlib --strip-components=1 &
tar -xf packages/gdb-*.tar.* -C build/gdb --strip-components=1 &
wait

# build binutils
pushd build/binutils
mkdir build && cd build
../configure --target=$TARGET --prefix=$PREFIX \
    --enable-tls --disable-werror \
    --enable-soft-float
make -j$(nproc)
make install
popd

# build gcc with newlib
pushd build/gcc
cp -a ../newlib/newlib .
cp -a ../newlib/libgloss .
./contrib/download_prerequisites
mkdir build && cd build
../configure --target=$TARGET --prefix=$PREFIX \
    --disable-shared --disable-threads \
    --enable-tls --enable-languages=c,c++ \
    --with-newlib --disable-libmudflap \
    --disable-libssp --disable-libquadmath \
    --disable-libgomp --disable-nls \
    --enable-soft-float --with-arch=$ARCH
make -j$(nproc) inhibit-libc=true
make install
popd

# build gdb
pushd build/gdb
mkdir build && cd build
../configure --target=$TARGET --prefix=$PREFIX \
    --with-arch=$ARCH --with-abi=$ABI --disable-werror
make -j$(nproc)
make install
popd

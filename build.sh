#/bin/env bash

# This script is kind of crude and would have probably been better off written as a Makefile, but it works.

# exit on errors
set -e

# show progress
set -x

# toolchain properties
TARGET=riscv32-unknown-elf
NAME=gcc-$TARGET
PREFIX=$PWD/build-root
PATH=$PREFIX/bin:$PATH
ARCH=rv32im
TOP_DIR=$PWD
BUILD_DIR=$TOP_DIR/build
PACKAGES_DIR=$TOP_DIR/packages

# create build directories
mkdir -p $BUILD_DIR/binutils
mkdir -p $BUILD_DIR/gcc
mkdir -p $BUILD_DIR/newlib
mkdir -p $BUILD_DIR/gdb
mkdir -p $PACKAGES_DIR

# define sources and extraction targets
declare -A sources=(
    [binutils]="https://ftp.gnu.org/gnu/binutils/binutils-2.43.tar.xz"
    [gcc]="https://gcc.gnu.org/pub/gcc/releases/gcc-14.2.0/gcc-14.2.0.tar.xz"
    [gdb]="https://ftp.gnu.org/gnu/gdb/gdb-15.2.tar.xz"
    [newlib]="ftp://sourceware.org/pub/newlib/newlib-4.4.0.20231231.tar.gz"
)

declare -A extract_targets=(
    [binutils]="binutils"
    [gcc]="gcc"
    [gdb]="gdb"
    [newlib]="newlib"
)

# download sources
cd $PACKAGES_DIR
for pkg in "${!sources[@]}"; do
    file=$(basename "${sources[$pkg]}")
    if [[ ! -f $file ]]; then
        wget -q "${sources[$pkg]}" &
    fi
done
wait  # Wait for all downloads to finish

# extract sources
cd $BUILD_DIR
for pkg in "${!sources[@]}"; do
    file=$(basename "${sources[$pkg]}")
    tar -xf $PACKAGES_DIR/$file -C ${extract_targets[$pkg]} --strip-components=1 &
done
wait  # Wait for all extractions to finish
cd $TOP_DIR

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

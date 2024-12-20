#/bin/env bash

# exit on errors
set -e

# show progress
set -x

# toolchain properties
export TARGET=riscv32-unknown-elf
export NAME=gcc-$TARGET
export PREFIX=$PWD/build-root
export ARCH=rv32im
export PATH=$PREFIX/bin:$PATH

# # create build directories
# mkdir -p build/binutils
# mkdir -p build/gcc
# mkdir -p build/newlib
# mkdir -p build/gdb

# # extract sources
# tar -xf packages/binutils-*.tar.* -C build/binutils --strip-components=1 &
# tar -xf packages/gcc-*.tar.* -C build/gcc --strip-components=1 &
# tar -xf packages/newlib-*.tar.* -C build/newlib --strip-components=1 &
# tar -xf packages/gdb-*.tar.* -C build/gdb --strip-components=1 &
# wait

# # build binutils
# pushd build/binutils
# mkdir build && cd build
# ../configure --target=$TARGET --prefix=$PREFIX \
#     --with-arch=$ARCH --disable-werror
# make -j$(nproc)
# make install
# popd

# # build gcc (stage 1)
# pushd build/gcc
# ./contrib/download_prerequisites
# mkdir build1 && cd build1
# ../configure --target=$TARGET --prefix=$PREFIX \
#     --with-arch=$ARCH --enable-languages=c --disable-fixincludes \
#     --without-headers --disable-shared --disable-threads \
#     --disable-libatomic --disable-libgomp --disable-libmudflap \
#     --disable-libquadmath --disable-libssp --disable-libstdcxx \
#     --disable-nls
# make all-gcc -j$(nproc)
# make install-gcc
# popd

# # build newlib
# pushd build/newlib
# mkdir build && cd build
# ../configure --target=$TARGET --prefix=$PREFIX \
#     --with-arch=$ARCH
# make -j$(nproc)
# make install
# popd

# # build gcc (stage 2)
# pushd build/gcc
# mkdir build2 && cd build2
# ../configure --target=$TARGET --prefix=$PREFIX \
#     --with-arch=$ARCH --enable-languages=c,c++ --disable-fixincludes \
#     --disable-shared --disable-threads --disable-libssp \
#     --disable-nls --with-newlib
# make -j$(nproc)
# make install
# popd

# # build gdb
# pushd build/gdb
# mkdir build && cd build
# ../configure --target=$TARGET --prefix=$PREFIX \
#     --with-arch=$ARCH --disable-werror
# make -j$(nproc)
# make install
# popd

mkdir -p $PREFIX
touch "$PREFIX/foo"

# package toolchain
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
ARCHIVE_NAME="$TARGET-$TIMESTAMP.tar.bz2"
mkdir -p archive/$TARGET
mv "$PREFIX/*" "archive/$TARGET/"
tar -cf - -C archive $TARGET | pbzip2 -c -p$(nproc) > $ARCHIVE_NAME

# Check if GITHUB_TOKEN is available
if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "Error: GITHUB_TOKEN is not set."
    exit 1
fi

# Upload the archive as a GitHub release asset
TAG="release-$TIMESTAMP"
RELEASE_NAME="$TARGET"
UPLOAD_URL="https://uploads.github.com/repos/$GITHUB_REPOSITORY/releases"

# Create a new release
RELEASE_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"tag_name\": \"$TAG\", \"name\": \"$RELEASE_NAME\", \"body\": \"Toolchain build uploaded.\", \"draft\": false, \"prerelease\": false}" \
    "https://api.github.com/repos/$GITHUB_REPOSITORY/releases")

RELEASE_ID=$(echo "$RELEASE_RESPONSE" | jq -r '.id')

if [[ "$RELEASE_ID" == "null" ]]; then
    echo "Error: Failed to create release."
    echo "$RELEASE_RESPONSE"
    exit 1
fi

# Upload the archive
curl -s -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/octet-stream" \
    --data-binary @"$ARCHIVE_NAME" \
    "$UPLOAD_URL/$RELEASE_ID/assets?name=$(basename "$ARCHIVE_NAME")"

echo "Release uploaded successfully."

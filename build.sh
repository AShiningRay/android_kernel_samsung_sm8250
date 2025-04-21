#!/bin/bash

# Sets some shortcuts for terminal colors
COLOR_N="\033[0m"
COLOR_R="\033[0;31m"
COLOR_G="\033[1;32m"
COLOR_C="\033[0;36m"
COLOR_Y="\033[1;33m"

CLANG=$HOME/toolchains/clang/bin/
GCC32=$HOME/toolchains/gcc32/bin/
GCC64=$HOME/toolchains/gcc64/bin/

export PATH="$CLANG:$GCC64:$GCC32:$PATH"

KONA_CONFIG=vendor/kona-sec-perf_defconfig
DBGFS_CONFIG=vendor/debugfs.config
R8Q_CONFIG=vendor/samsung/r8q.config
SWAN_CONFIG=vendor/samsung/swankernel.config

check_path() {
    if [ ! -d "$1" ]; then
        echo -e "${COLOR_R}Error: Directory $1 does not exist.${COLOR_N}"
        exit 1
    fi
}

clean_build()
{
        echo -e $COLOR_C"Cleaning build folder..."$COLOR_N
        rm -rf kernelOut
        mkdir kernelOut
        echo -e $COLOR_G"Build folder was cleaned!"$COLOR_N
        build_kernel
}


build_kernel()
{
        # Configure the kernel
        echo -e "${COLOR_C}\nConfiguring the kernel...${COLOR_N}"
        make O=kernelOut ARCH=arm64 $KONA_CONFIG $DBGFS_CONFIG $R8Q_CONFIG $SWAN_CONFIG || {
        echo -e "${COLOR_R}Configuration failed. Check for errors above.${COLOR_N}"
        exit 1
        }
        echo -e "${COLOR_G}\n\nConfiguration done. Now building for S20FE (r8q).\n\n${COLOR_N}"

        # Build the kernel
        make -j$(nproc --all) LLVM_IAS=1 LLVM=-14 \
        CC=clang CLANG_TRIPLE=aarch64-linux-gnu- \
        CROSS_COMPILE=aarch64-linux-android- CROSS_COMPILE_ARM32=arm-linux-androideabi- \
        O=kernelOut ARCH=arm64 EXTRA_CFLAGS="-Wno-error" || {
        echo -e "${COLOR_R}The kernel couldn't be compiled... check for errors above.${COLOR_N}"
        exit 1
        }

        echo -e "${COLOR_G}The kernel has been compiled successfully!${COLOR_N}"
}

# Check compiler paths
echo -e "${COLOR_C}Checking compiler paths...${COLOR_N}"
check_path "$CLANG"
check_path "$GCC32"
check_path "$GCC64"
echo -e "${COLOR_G}Compiler paths are valid.${COLOR_N}"

if [ -f "$(pwd)/kernelOut/.config" ]; then
        while true; do
                echo -e $COLOR_Y
                echo -e "There's already a previous build config, you can opt to rebuild only the files that were changed."
                echo -e "If you opt not to, the build folder will be cleaned and a clean rebuild will be triggered.\n "
                read -p "Would you like to rebuild only the changes (y or n)? " yn
                echo -e $COLOR_N
                case $yn in
                [Nn]* ) clean_build && break ;;
                [Yy]* ) build_kernel && break ;;
                * ) echo -e $COLOR_R"Please answer either y or n" $COLOR_N ;;
                esac
        done
else
        echo -e $COLOR_C"No previous build config found, doing a clean build..." $COLOR_N
        build_kernel
fi

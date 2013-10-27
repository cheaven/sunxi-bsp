#!/bin/bash

TMPDIR=$PWD"/livesuilt-cb-tmp-dir"


cleanup() {
	sudo sudo rm -rf $TMPDIR
}

die() {
	echo "$*" >&2
	cleanup
	exit 1
}

set -e

make_rootfs()
{
	echo "Make rootfs"
	local rootfs=$(readlink -f "$1")
        local hwpack=$(readlink -f "$2")
        local output=$(readlink -f "$3")
        local rootfs_size= total_size=
        local hwlib_size=
        local libs_size=
        
        local rootfs_copied=

        echo "Prepare tmp dir..."
        sudo rm -rf $TMPDIR
        mkdir -p $TMPDIR/rootfs $TMPDIR/rootfstmp
        mkdir -p $TMPDIR/hwpack
        
        echo "Unpacking $rootfs"
	sudo tar -C $TMPDIR/rootfstmp xzpf $rootfs --numeric-owner || die "Unable to extract rootfs"
	for x in '' \
		'binary/boot/filesystem.dir' 'binary'; do

		d="$TMPDIR/rootfstmp${x:+/$x}"

		if [ -d "$d/sbin" ]; then
			rootfs_copied=1
			sudo mv "$d"/* $TMPDIR/rootfs/ ||
				die "Failed to copy rootfs data"
			break
		fi
	done


	[ -n "$rootfs_copied" ] || die "Unsupported rootfs"
        
        sudo tar -C $TMPDIR/hwpack -xf $hwpack
        sudo rm -r -f $TMPDIR/rootfstmp

        echo "Move data in hwpack to rootfs..."
        sudo mv -f $TMPDIR/hwpack/rootfs/* $TMPDIR/rootfs/

        echo "Calcuate size requirement..."
        total_size=$(sudo du -s $TMPDIR/rootfs| awk '{print $1}')

        total_size=$(expr $total_size / 1024 + 100)
        rootfs_size=$(expr ${total_size} + 50)

        echo "Create image file"

        dd if=/dev/zero of=$TMPDIR/rootfs.ext4 bs=1M count="$rootfs_size"
        mkfs.ext4 -F $TMPDIR/rootfs.ext4

        echo "Install to target"
        mkdir $TMPDIR/target
        sudo mount -o loop -t ext4 $TMPDIR/rootfs.ext4 $TMPDIR/target

        (cd $TMPDIR/rootfs/; sudo tar -c *) |sudo tar -C $TMPDIR/target/ -x
        sudo $TMPDIR/target
        mv $TMPDIR/rootfs.ext4  $output
}

[ $# -eq 2 ] || die "Usage: $0 [rootfs.tar.gz] [output]"

make_rootfs "$1" "$2"
cleanup


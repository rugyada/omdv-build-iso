#!/bin/bash

# OpenMandriva Association 2012
# Original author: Bernhard Rosenkraenzer <bero@lindev.ch>
# Modified on 2014 by: Tomasz Pawe� Gajc <tpgxyz@gmail.com>
# Modified on 2015 by: Tomasz Pawe� Gajc <tpgxyz@gmail.com>
# Modified on 2015 by: Colin Close <itchka@compuserve.com>
# Modified on 2015 by: Crispin Boylan <cris@beebgames.com>

# This tool is licensed under GPL license
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#

# This tools is specified to build OpenMandriva Lx distribution ISO

usage_help() {

    if [[ -z $EXTARCH && -z $TREE && -z $VERSION && -z $RELEASE_ID && -z $TYPE && -z $DISPLAYMANAGER ]]; then
	echo ""
	echo "Please run script with arguments."
        echo ""
	echo "usage $0 [options]"
        echo ""
        echo " general options:"
        echo " --arch= Architecture of packages: i586, x86_64"
        echo " --tree= Branch of software repository: cooker, openmandriva2014.0"
        echo " --version= Version for software repository: 2015.0, 2014.1, 2014.0"
        echo " --release_id= Release identifer: alpha, beta, rc, final"
        echo " --type= User environment type on ISO: Plasma, KDE4, MATE, LXQt, IceWM, hawaii, xfce4, weston, minimal"
        echo " --displaymanager= Display Manager used in desktop environemt: KDM, GDM, LightDM, sddm, xdm, none"
        echo " --workdir= Set directory where ISO will be build"
        echo " --outputdir= Set destination directory to where put final ISO file"
        echo " --debug Enable debug output"
        echo " --noclean Do not clean build chroot and keep cached rpms"
        echo " --rebuild Clean build chroot and rebuild from cached rpm"
        echo " --boot-kernel-type Type of kernel to use for syslinux (eg nrj-desktop), if different from standard kernel"
        echo ""
        echo "For example:"
        echo "omdv-build-iso.sh --arch=x86_64 --tree=cooker --version=2015.0 --release_id=alpha --type=lxqt --displaymanager=sddm"
        echo ""
        echo "Exiting."
	exit 1
    else
	return 0
    fi
}

# use only allowed arguments
if [ $# -ge 1 ]; then
    for k in "$@"; do
	case "$k" in
		--arch=*)
        	    EXTARCH=${k#*=}
        	    shift
        	    ;;
    		--tree=*)
        	    TREE=${k#*=}
        	    shift
        	    ;;
		--version=*)
        	    VERSION=${k#*=}
        	    if [[ "${VERSION,,}" == "cooker" ]]
        	    then
        		VERSION="`date +%Y.0`"
        	    fi
        	    shift
        	    ;;
    		--release_id=*)
        	    RELEASE_ID=${k#*=}
        	    shift
        	    ;;
                --boot-kernel-type=*)
                   BOOT_KERNEL_TYPE=${k#*=}
                  shift
                  ;;
		--type=*)
		    declare -l lc
		    lc=${k#*=}
			case "$lc" in
			    plasma)
				TYPE=PLASMA
				;;
			    kde4)
				TYPE=KDE4
				;;
			    mate)
				TYPE=MATE
				;;
			    lxqt)
				TYPE=LXQt
				;;
			    icewm)
				TYPE=IceWM
				;;
			    hawaii)
				TYPE=hawaii
				;;
			    xfce4)
				TYPE=xfce4
				;;
			    weston)
				TYPE=weston
				;;
			    minimal)
				TYPE=minimal
				;;
			    *)
				echo "$TYPE is not supported."
				usage_help
				;;
			esac
        	    shift
        	    ;;
    		--displaymanager=*)
        	    DISPLAYMANAGER=${k#*=}
        	    shift
        	    ;;
        	--workdir=*)
        	    WORKDIR=${k#*=}
        	    shift
        	    ;;
        	--outputdir=*)
        	    OUTPUTDIR=${k#*=}
        	    shift
        	    ;;
    		--debug)
        	    DEBUG=debug
        	    shift
        	    ;;
        	--noclean)
        	    NOCLEAN=noclean
        	    shift
        	    ;;
               --rebuild)
                   REBUILD=0
                   shift
                   ;;
        	--help)
        	    usage_help
        	    ;;
    		*)
		    usage_help
        	    ;;
	    esac
	shift
    done
else
    usage_help
fi

# We lose our cli variables when we invoke sudo so we save them
# and pass them to sudo when it is started. Also the user name is needed.

OLDUSER=`echo ~ | awk 'BEGIN { FS="/" } {print $3}'`
SUDOVAR=""UHOME="$HOME "EXTARCH="$EXTARCH "TREE="$TREE "VERSION="$VERSION "RELEASE_ID="$RELEASE_ID "TYPE="$TYPE "DISPLAYMANAGER="$DISPLAYMANAGER "DEBUG="$DEBUG "NOCLEAN="$NOCLEAN "EFIBUILD="$EFIBUILD "OLDUSER="$OLDUSER "WORKDIR="$WORKDIR "OUTPUTDIR="$OUTPUTDIR "REBUILD="$REBUILD"
export $SUDOVAR

    # run only when root
if [ "`id -u`" != "0" ]; then
    # We need to be root for umount and friends to work...
    # NOTE the following command will only work on OMDV for the first registered user
    # this user is a member of the wheel group and has root privelidges 

    exec sudo -E `echo $SUDOVAR` $0 "$@"
    echo "Run me as root."
    exit 1
fi

# check whether script is executed inside ABF (www.abf.io)
if echo $(realpath $(dirname $0)) | grep -q /home/vagrant; then
    ABF=1
    echo "This is $NOCLEAN"
    if [ -n "$NOCLEAN" ]; then
	echo "You cannot use --noclean inside ABF"
	exit 1
    fi

    if [ -n "$WORKDIR" ]; then
	echo "You cannot use --workdir inside ABF"
	exit 1
    fi

    # hardcode workdir for ABF
    WORKDIR=$(realpath $(dirname $0))
fi

# default definitions
DIST=omdv
[ -z "$EXTARCH" ] && EXTARCH=`uname -m`
[ -z "${TREE}" ] && TREE=cooker
[ -z "${VERSION}" ] && VERSION="`date +%Y.0`"
[ -z "${RELEASE_ID}" ] && RELEASE_ID=alpha
[ -z "${DEBUG}" ] && DEBUG="nodebug"
[ -z "${BUILD_ID}" ] && BUILD_ID=$(($RANDOM%9999+1000))

# always build free ISO
FREE=1

SUDO="sudo -E"
[ "`id -u`" = "0" ] && SUDO=""
LOGDIR="."

# set up main working directory if it was not set up
if [ -z "$WORKDIR" ]; then
    if [ -z "$ABF" ]; then
	# set up working directory
	WORKDIR="$UHOME/omdv-build-chroot-$EXTARCH"

	# create working directory
	if [ ! -d $WORKDIR ]; then
	    $SUDO mkdir -p $WORKDIR
	elif [ -z "$NOCLEAN" ]; then
	    $SUDO rm -rf $WORKDIR
	fi

	# copy contents to the workdir
	if [ -e /usr/share/omdv-build-iso ]; then
	    $SUDO cp -r /usr/share/omdv-build-iso/* $WORKDIR
	else
	    echo "Directory /usr/share/omdv-build-iso does not exist. Please install omdv-build-iso"
	    exit 1
	fi

    else
	# Yes we are inside ABF
	WORKDIR="`mktemp -d /tmp/isobuildrootXXXXXX`"
    fi
elif [ -n "$WORKDIR" ] && [ -z "$ABF" ]; then

	# create working directory
	if [ ! -d $WORKDIR ]; then
	    $SUDO mkdir -p $WORKDIR
	elif [ -z "$NOCLEAN" ]; then
	    $SUDO rm -rf $WORKDIR
	fi

	# copy contents to the workdir
	if [ -d /usr/share/omdv-build-iso ]; then
	    $SUDO cp -r /usr/share/omdv-build-iso/* $WORKDIR
	else
	    echo "Directory /usr/share/omdv-build-iso does not exist. Please install omdv-build-iso"
	    exit 1
	fi
fi

# this is where rpm are installed
CHROOTNAME="$WORKDIR"/BASE
# this is where ISO image is prepared based on above
ISOROOTNAME="$WORKDIR"/ISO

# UUID Generation. xorriso needs a string of 16 asci digits.
# grub2 needs dashes to separate the fields..
GRUB_UUID="`date -u +%Y-%m-%d-%H-%M-%S-00`"
ISO_DATE="`echo $GRUB_UUID | sed -e s/-//g`"
# in case when i386 is passed, fall back to i586
[ "$EXTARCH" = "i386" ] && EXTARCH=i586

# ISO name logic
if [ "${RELEASE_ID,,}" == "final" ]; then
    PRODUCT_ID="OpenMandrivaLx.$VERSION-$TYPE"
else
    if [[ "${RELEASE_ID,,}" == "alpha" ]]; then
	RELEASE_ID="$RELEASE_ID.`date +%Y%m%d`"
    fi
    PRODUCT_ID="OpenMandrivaLx.$VERSION-$RELEASE_ID-$TYPE"
fi

LABEL="$PRODUCT_ID.$EXTARCH"
[ `echo $LABEL | wc -m` -gt 32 ] && LABEL="OpenMandrivaLx_$VERSION"
[ `echo $LABEL | wc -m` -gt 32 ] && LABEL="`echo $LABEL |cut -b1-32`"

# start functions
umountAll() {
    echo "Umounting all."
    unset KERNEL_ISO
    $SUDO umount -l "$1"/proc || :
    $SUDO umount -l "$1"/sys || :
    $SUDO umount -l "$1"/dev/pts || :
    $SUDO umount -l "$1"/dev || :
    $SUDO umount -l "$1"/run/os-prober/dev/* || :
}

errorCatch() {
    echo "Something went wrong. Exiting"
    unset KERNEL_ISO
    unset UEFI
    unset MIRRORLIST
if [ -z "$DEBUG" ] || [ -z "$NOCLEAN" ]; then
    $SUDO rm -rf $(dirname "$FILELISTS")
    umountAll "$CHROOTNAME"
    $SUDO rm -rf "$ROOTNAME"
else
    umountAll "$CHROOTNAME"
fi
    exit 1
}

# Don't leave potentially dangerous stuff if we had to error out...
trap errorCatch ERR SIGHUP SIGINT SIGTERM

updateSystem() {

    # Force update of critical packages
    if [ -n "$ABF" ]; then
	echo "We are inside ABF (www.abf.io). Updating packages."
	$SUDO urpmq --list-url
	$SUDO urpmi.update -ff updates

	# inside ABF, lxc-container which is used to run this script is based
	# on Rosa2012 which does not have cdrtools
	echo "Installing rpms files"
	$SUDO urpmi --downloader wget --wget-options --auth-no-challenge --auto --no-suggests --no-verify-rpm --ignorearch perl-URPM dosfstools grub2 xorriso syslinux squashfs-tools bc imagemagick gptfdisk kpartx --prefer /distro-theme-OpenMandriva-grub/ --prefer /distro-release-OpenMandriva/ --auto
    elif  [ ! -f "$CHROOTNAME"/.noclean ]; then
	echo "Building in user custom environment will clean rpm cache"
	$SUDO urpmi --downloader wget --wget-options --auth-no-challenge --auto --no-suggests --no-verify-rpm --ignorearch perl-URPM dosfstools grub2 xorriso syslinux grub2 squashfs-tools bc imagemagick gptfdisk kpartx --prefer /distro-theme-OpenMandriva-grub/ --prefer /distro-release-OpenMandriva/ --auto
    else
	echo "Building in user custom environment will keep rpm cache"
	$SUDO urpmi --noclean --downloader wget --wget-options --auth-no-challenge --auto --no-suggests --no-verify-rpm --ignorearch perl-URPM dosfstools grub2 xorriso syslinux grub2 squashfs-tools bc imagemagick gptfdisk kpartx --prefer /distro-theme-OpenMandriva-grub/ --prefer /distro-release-OpenMandriva/ --auto
    fi
}

getPkgList() {

    # Support for building released isos
    if [ ${TREE,,} = "cooker" ]; then
        BRANCH=cooker
    else
        BRANCH="$TREE"
    fi

    # update iso-pkg-lists from ABF if missing
    # we need to do this for ABF to ensure any edits have been included
    # Do we need to do this if people are using the tool locally?

    if [ ! -d $WORKDIR/iso-pkg-lists-$BRANCH ]; then
	echo "Could not find $WORKDIR/iso-pkg-lists-$BRANCH. Downloading from ABF."
	# download iso packages lists from www.abf.io
	PKGLIST="https://abf.io/openmandriva/iso-pkg-lists/archive/iso-pkg-lists-$BRANCH.tar.gz"
	$SUDO  wget --tries=10 -O `echo "$WORKDIR/iso-pkg-lists-$BRANCH.tar.gz"` --content-disposition $PKGLIST
	$SUDO tar zxfC $WORKDIR/iso-pkg-lists-$BRANCH.tar.gz $WORKDIR
	# Why not retain the unique list name it will help when people want their own spins ?
	$SUDO rm -f iso-pkg-lists-$BRANCH.tar.gz
   fi

    # export file list
    FILELISTS="$WORKDIR/iso-pkg-lists-$BRANCH/${DIST,,}-${TYPE,,}.lst"

    if [ ! -e "$FILELISTS" ]; then
	echo "$FILELISTS does not exists. Exiting"
	errorCatch
    fi
}

showInfo() {
    echo $'###\n'
    echo "Building ISO with arguments:"
    echo "Distribution is $DIST"
    echo "Architecture is $EXTARCH"
    echo "Tree is $TREE"
    echo "Version is $VERSION"
    echo "Release ID is $RELEASE_ID"
    echo "Type is $TYPE"
    if [ "${TYPE,,}" = "minimal" ]; then
	echo "No display manager for minimal ISO."
    else
	echo "Display Manager is $DISPLAYMANAGER"
    fi
    echo "ISO label is $LABEL"
    echo "Build ID is $BUILD_ID"
    echo "Working directory is $WORKDIR"
    echo $'###\n'
}

# Usage: parsePkgList xyz.lst
# Shows the list of packages in the package list file (including any packages
# mentioned by other package list files being %include-d)
parsePkgList() {
    LINE=0
    cat "$1" | while read r; do
	LINE=$((LINE+1))
	SANITIZED="`echo $r | sed -e 's,	, ,g;s,  *, ,g;s,^ ,,;s, $,,;s,#.*,,'`"
	[ -z "$SANITIZED" ] && continue
	if [ "`echo $SANITIZED | cut -b1-9`" = "%include " ]; then
	    INC="$(dirname "$1")/`echo $SANITIZED | cut -b10- | sed -e 's/^\..*\///g'`"
	    if ! [ -e "$INC" ]; then
		echo "ERROR: Package list doesn't exist: $INC (included from $1 line $LINE)" >&2
		errorCatch
	    fi
		parsePkgList $(dirname "$1")/"`echo $SANITIZED | cut -b10- | sed -e 's/^\..*\///g'`"
		continue
	fi
	echo $SANITIZED
    done
}

# Usage: createChroot packages.lst /target/dir
# Creates a chroot environment with all packages in the packages.lst
# file and their dependencies in /target/dir
createChroot() {

    # path to repository
    if [ "${TREE,,}" == "cooker" ]; then
	REPOPATH="http://abf-downloads.abf.io/$TREE/repository/$EXTARCH/"
    else
	REPOPATH="http://abf-downloads.abf.io/$TREE/repository/$EXTARCH/"
    fi

    echo "Creating chroot $CHROOTNAME"
    # Make sure /proc, /sys and friends are mounted so %post scripts can use them
    $SUDO mkdir -p "$CHROOTNAME"/proc "$CHROOTNAME"/sys "$CHROOTNAME"/dev "$CHROOTNAME"/dev/pts

    # Do not clean build chroot
    if [ ! -f "$CHROOTNAME"/.noclean ]; then
	if [ -n "$NOCLEAN" ]; then
	    touch "$CHROOTNAME"/.noclean
	fi

	if [ ! -f "$CHROOTNAME"/.noclean ]; then
	    echo "Adding urpmi repository $REPOPATH into $CHROOTNAME"
	    if [ "$FREE" = "0" ]; then
		$SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" --distrib $REPOPATH
	    else
		$SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" "Main" $REPOPATH/main/release
		$SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" "Contrib" $REPOPATH/contrib/release
		# this one is needed to grab firmwares
		$SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" "Non-free" $REPOPATH/non-free/release

		if [ "${TREE,,}" != "cooker" ]; then
		    $SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" "MainUpdates" $REPOPATH/main/updates
		    $SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" "ContribUpdates" $REPOPATH/contrib/updates
		    # this one is needed to grab firmwares
		    $SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" "Non-freeUpdates" $REPOPATH/non-free/updates
		fi
	    fi
	fi

	    # update medias
	    $SUDO urpmi.update -a -c -ff --wget --urpmi-root "$CHROOTNAME" main
	    if [ "${TREE,,}" != "cooker" ]; then
		echo "Updating urpmi repositories in $CHROOTNAME"
		$SUDO urpmi.update -a -c -ff --wget --urpmi-root "$CHROOTNAME" updates
	    fi

	    $SUDO mount --bind /proc "$CHROOTNAME"/proc
	    $SUDO mount --bind /sys "$CHROOTNAME"/sys
	    $SUDO mount --bind /dev "$CHROOTNAME"/dev
	    $SUDO mount --bind /dev/pts "$CHROOTNAME"/dev/pts

	    # start rpm packages installation
	    # but only if .noclean does not exist
	    if [ ! -f "$CHROOTNAME"/.noclean ]; then
		echo "Start installing packages in $CHROOTNAME"
		parsePkgList "$FILELISTS" | xargs $SUDO urpmi --urpmi-root "$CHROOTNAME" --download-all --no-suggests --no-verify-rpm --fastunsafe --ignoresize --nolock --auto

		if [[ $? != 0 ]] && [ ${TREE,,} != "cooker" ]; then
		    echo "Can not install packages from $FILELISTS";
		    errorCatch
		fi

		if [ ! -e "$CHROOTNAME"/usr/lib/syslinux/isolinux.bin ]; then
		    echo "Syslinux is missing in chroot. Installing it."
		    $SUDO urpmi --urpmi-root "$CHROOTNAME" --no-suggests --no-verify-rpm --fastunsafe --ignoresize --nolock --auto syslinux
		fi
	    fi
    fi #noclean

    # check CHROOT
    if [ ! -d  "$CHROOTNAME"/lib/modules ]; then
	echo "Broken chroot installation. Exiting"
	errorCatch
    fi

    # export installed and boot kernel
    pushd "$CHROOTNAME"/lib/modules
    BOOT_KERNEL_ISO=`ls -d --sort=time [0-9]*-${BOOT_KERNEL_TYPE}* | head -n1 | sed -e 's,/$,,'`
    export BOOT_KERNEL_ISO
    if [ -n "$BOOT_KERNEL_TYPE" ]; then
	$SUDO echo $BOOT_KERNEL_TYPE > "$CHROOTNAME"/boot_kernel
	KERNEL_ISO=`ls -d --sort=time [0-9]* | grep -v $BOOT_KERNEL_TYPE | head -n1 | sed -e 's,/$,,'`
    else
	KERNEL_ISO=`ls -d --sort=time [0-9]* |head -n1 | sed -e 's,/$,,'`
    fi
    export KERNEL_ISO
    popd

    # remove rpm db files which may not match the target chroot environment
    $SUDO chroot "$CHROOTNAME" rm -f /var/lib/rpm/__db.*

}

createInitrd() {

    # check if dracut is installed
    if [ ! -f "$CHROOTNAME"/usr/sbin/dracut ]; then
	echo "dracut is not installed inside chroot. Exiting."
	errorCatch
    fi

    # build initrd for syslinux
    echo "Building liveinitrd-$BOOT_KERNEL_ISO for ISO boot"
    if [ ! -f "$WORKDIR"/dracut/dracut.conf.d/60-dracut-isobuild.conf ]; then
	echo "Missing "$WORKDIR"/dracut/dracut.conf.d/60-dracut-isobuild.conf . Exiting."
	errorCatch
    fi

    $SUDO cp -f "$WORKDIR"/dracut/dracut.conf.d/60-dracut-isobuild.conf "$CHROOTNAME"/etc/dracut.conf.d/60-dracut-isobuild.conf

    if [ ! -d "$CHROOTNAME"/usr/lib/dracut/modules.d/90liveiso ]; then
	echo "Dracut is missing 90liveiso module. Installing it."

	if [ ! -d "$WORKDIR"/dracut/90liveiso ]; then
	    echo "Cant find 90liveiso dracut module in $WORKDIR/dracut. Exiting."
	    errorCatch
	fi

	$SUDO cp -a -f "$WORKDIR"/dracut/90liveiso "$CHROOTNAME"/usr/lib/dracut/modules.d/
	$SUDO chmod 0755 "$CHROOTNAME"/usr/lib/dracut/modules.d/90liveiso
	$SUDO chmod 0755 "$CHROOTNAME"/usr/lib/dracut/modules.d/90liveiso/*.sh
    fi

    # fugly hack to get /dev/disk/by-label
    $SUDO sed -i -e '/KERNEL!="sr\*\", IMPORT{builtin}="blkid"/s/sr/none/g' -e '/TEST=="whole_disk", GOTO="persistent_storage_end"/s/TEST/# TEST/g' "$CHROOTNAME"/lib/udev/rules.d/60-persistent-storage.rules

    if [ -f "$CHROOTNAME"/boot/liveinitrd.img ]; then
	$SUDO rm -rf "$CHROOTNAME"/boot/liveinitrd.img
    fi

    # set default plymouth theme
    if [ -x "$CHROOTNAME"/usr/sbin/plymouth-set-default-theme ]; then
	chroot "$CHROOTNAME" /usr/sbin/plymouth-set-default-theme OpenMandriva
    fi

    # building liveinitrd
    $SUDO chroot "$CHROOTNAME" /usr/sbin/dracut -N -f --no-early-microcode --nofscks --noprelink  /boot/liveinitrd.img --conf /etc/dracut.conf.d/60-dracut-isobuild.conf $KERNEL_ISO

    if [ ! -f "$CHROOTNAME"/boot/liveinitrd.img ]; then
	echo "File "$CHROOTNAME"/boot/liveinitrd.img does not exist. Exiting."
	errorCatch
    fi

    echo "Building initrd-$KERNEL_ISO inside chroot"
    # remove old initrd
    $SUDO rm -rf "$CHROOTNAME"/boot/initrd-$KERNEL_ISO.img
    $SUDO rm -rf "$CHROOTNAME"/boot/initrd0.img

    # remove config before building initrd
    $SUDO rm -rf "$CHROOTNAME"/etc/dracut.conf.d/60-dracut-isobuild.conf
    $SUDO rm -rf "$CHROOTNAME"/usr/lib/dracut/modules.d/90liveiso

    # building initrd
    $SUDO chroot "$CHROOTNAME" /usr/sbin/dracut -N -f /boot/initrd-$KERNEL_ISO.img $KERNEL_ISO

    if [[ $? != 0 ]]; then
	echo "Failed creating initrd. Exiting."
	errorCatch
    fi

    # build the boot kernel initrd in case the user wants it kept
    if [ -n "$BOOT_KERNEL_TYPE" ]; then
        # building boot kernel initrd
        echo "Building initrd-$BOOT_KERNEL_ISO inside chroot"
        $SUDO chroot "$CHROOTNAME" /usr/sbin/dracut -N -f /boot/initrd-$BOOT_KERNEL_ISO.img $BOOT_KERNEL_ISO

	if [[ $? != 0 ]]; then
	    echo "Failed creating boot kernel initrd. Exiting."
	    errorCatch
	fi
    fi

    $SUDO ln -sf /boot/initrd-$KERNEL_ISO.img "$CHROOTNAME"/boot/initrd0.img

}

# Usage: createEFI <target_directory/image_name>.img <grub_support_files_directory> <grub2 efi executable>
# Creates a fat formatted file ifilesystem image which will boot an UEFI system.
createUEFI() {

    if [ $EXTARCH = "x86_64" ]; then
	EFIARCH=X64
    else
        EFIARCH="IA32"
    fi

    echo "Setting up UEFI partiton and image."

    IMGNME="$ISOROOTNAME"/boot/grub/efiboot.img
    GRB2FLS="$ISOROOTNAME"/EFI/BOOT

    # Get sizes of the required EFI files in blocks.
    # efipartsize  must be large enough to accomodate a gpt partition tables as well as the data.
    # each table is 17408 and there are two of them.a
    EFIFILESIZE=`du -s --block-size=512 "$ISOROOTNAME/EFI" | awk '{print $1}'`
    PARTTABLESIZE=$(( (2*17408)/512 ))
    EFIDISKSIZE=$(( ( $EFIFILESIZE * 2 ) + $PARTTABLESIZE ))

    if [ -e $IMGNME ]; then
	$SUDO rm -rf $IMGNME
	$SUDO kpartx -d $IMGNME
    fi

    # Create the image.
    echo "Creating EFI image with size $EFIDISKSIZE"
    $SUDO dd if=/dev/zero of=$IMGNME  bs=512 count=$EFIDISKSIZE

    if [[ $? != 0 ]]; then
	echo "Failed creating UEFI image. Exiting."
	errorCatch
    fi

    # Mount the image on a loopdevice
    LDEV1=`losetup -f --show $IMGNME`

    # Add the fat partition
    $SUDO sgdisk -a 1 -n 1:34:"$EFIFILESIZE" -c 1:"EFI System Partition" -t 1:EF00 $LDEV1
    losetup -D
    sleep 1

    # Put the partition on /dev/mapper/
    LDEV="/dev/mapper/`kpartx -avs $IMGNME | awk {'print $3'}`"

    # Then make the filesystem
    $SUDO mkfs.vfat -s 1 -S 512 $LDEV
    $SUDO mount -t vfat $LDEV /mnt

    if [[ $? != 0 ]]; then
	echo "Failed to mount UEFI image. Exiting."
	errorCatch
    fi

    # copy the Grub2 files to the EFI image
    if [ ! -e /mnt/EFI/BOOT ]; then
	$SUDO mkdir -p /mnt/EFI/BOOT
    else
	$SUDO rm -rf /mnt/EFI/BOOT
    fi
    $SUDO cp -R $GRB2FLS/* /mnt/EFI/BOOT/
    echo "Made" >/mnt/EFI/BOOT/vnice

    # Unmout the filesystem with EFI image
    umount /mnt

    # Clean up
    $SUDO kpartx -d $IMGNME
}

# Usage: setupGrub2 /target/dir
# Sets up grub2 to boot /target/dir
setupGrub2() {

    if [ ! -e "$1"/usr/bin/grub2-mkimage ]; then
	echo "Missing grub2-mkimage in installation."
	errorCatch
    fi

    echo "Building Grub2 El-Torito image."

    GRUB_LIB=/usr/lib/grub/i386-pc
    GRUB_IMG=$(mktemp)

    mkdir -p "$2"/boot/grub "$2"/boot/grub/themes "$2"/boot/grub/locale "$2"/boot/grub/fonts
    $SUDO cp -f "$WORKDIR"/grub2/grub2-bios.cfg "$2"/boot/grub/grub.cfg
    $SUDO sed -i -e "s/%GRUB_UUID%/${GRUB_UUID}/g" "$2"/boot/grub/grub.cfg

    # copy memtest
    $SUDO cp -rfT $WORKDIR/extraconfig/memtest "$2"/boot/grub/memtest
    $SUDO chmod +x "$2"/boot/grub/memtest

    $SUDO cp -a -f "$1"/boot/grub2/themes "$2"/boot/grub/
    $SUDO cp -a -f "$1"/boot/grub2/locale "$2"/boot/grub//
    $SUDO cp -a -f "$1"/usr/share/grub/*.pf2 "$2"/boot/grub//fonts

    $SUDO /usr/bin/grub2-mkimage -d "$1"$GRUB_LIB -O i386-pc -o "$GRUB_IMG" -p /boot/grub -c "$2"/boot/grub/grub.cfg iso9660 all_video biosdisk boot cat chain configfile echo ext2 fat font gettext gfxmenu gfxterm gfxterm_background gzio halt help jpeg legacycfg linux linux16 loadenv ls minicmd multiboot multiboot2 normal part_gpt part_msdos png regexp reboot search search_fs_file search_fs_uuid search_label sleep test vbe vga

    if [[ $? != 0 ]]; then
	echo "Failed to create Grub2 El-Torito image. Exiting."
	errorCatch
    fi

    if [ -e "$2"/boot/grub/grub-eltorito.img -o -e "$2"/boot/grub/grub-embedded.img ]; then
	$SUDO rm -rf "$2"/boot/grub/{grub-eltorito,grub-embedded}.img
    fi

    $SUDO cat "$1"$GRUB_LIB/cdboot.img "$GRUB_IMG" > "$2"/boot/grub/grub-eltorito.img
    $SUDO cat "$1"$GRUB_LIB/boot.img "$GRUB_IMG" > "$2"/boot/grub/grub-embedded.img
    $SUDO rm -rf "$GRUB_IMG"

    # copy SuperGrub iso
    # do not copy it for now
#    $SUDO cp -rfT $WORKDIR/extraconfig/super_grub2_disk_i386_pc_2.00s2.iso "$2"/boot/grub/sgb.iso

    XORRISO_OPTIONS=" -b boot/grub/grub-eltorito.img -no-emul-boot -boot-info-table -boot-load-size 4 -boot-info-table --protective-msdos-label --grub2-boot-info --grub2-mbr "$1"$GRUB_LIB/boot_hybrid.img --embedded-boot "$2"/boot/grub/grub-embedded.img "

    echo "End building Grub2 El-Torito image."

    echo "Installing liveinitrd for grub2"

    if [ -e "$1"/boot/vmlinuz-$BOOT_KERNEL_ISO ] && [ -e "$1"/boot/liveinitrd.img ]; then
	$SUDO cp -a "$1"/boot/vmlinuz-$BOOT_KERNEL_ISO "$2"/boot/vmlinuz0
	$SUDO cp -a "$1"/boot/liveinitrd.img "$2"/boot/liveinitrd.img
    else
	echo "vmlinuz or liveinitrd does not exists. Exiting."
	errorCatch
    fi

    if [ ! -f "$2"/boot/liveinitrd.img ]; then
	echo "Missing /boot/liveinitrd.img. Exiting."
	errorCatch
    else
	$SUDO rm -rf "$1"/boot/liveinitrd.img
    fi

    # UEFI support
    if [ -f "$1"/boot/efi/EFI/openmandriva/grub.efi ]; then
	export UEFI=1
	$SUDO mkdir -m 0755 -p "$2"/EFI/BOOT "$2"/EFI/BOOT/fonts "$2"/EFI/BOOT/themes "$2"/EFI/BOOT/locale

	# For bootable iso's we may need grub.efi as BOOTX64.efi
	if [ "$EXTARCH" = "x86_64" ]; then
	    $SUDO cp -f "$1"/boot/efi/EFI/openmandriva/grub.efi "$2"/EFI/BOOT/BOOTX64.efi
	    $SUDO cp -f "$WORKDIR"/grub2/grub2-efi.cfg "$2"/EFI/BOOT/BOOTX64.cfg
	else
	    $SUDO cp -f "$1"/boot/efi/EFI/openmandriva/grub.efi "$2"/EFI/BOOT/BOOTIA32.efi
	    $SUDO cp -f $WORKDIR/EFI/grub.cfg "$2"/EFI/BOOT/BOOTIA32.cfg
	fi

	$SUDO cp -f "$WORKDIR"/grub2/grub2-efi.cfg "$2"/EFI/BOOT/grub.cfg
	$SUDO cp -f "$1"/boot/efi/EFI/openmandriva/grub.efi "$2"/EFI/BOOT/grub.efi

	$SUDO cp -a -f "$1"/boot/grub2/themes "$2"/EFI/BOOT/
	$SUDO cp -a -f "$1"/boot/grub2/locale "$2"/EFI/BOOT/
	$SUDO cp -a -f "$1"/usr/share/grub/*.pf2 "$2"/EFI/BOOT/fonts
	$SUDO sed -i -e "s/%GRUB_UUID%/${GRUB_UUID}/g" "$2"/EFI/BOOT/*.cfg
	sed -i -e "s/title-text.*/title-text: \"Welcome to OpenMandriva Lx $VERSION ${EXTARCH} ${TYPE} BUILD ID: ${BUILD_ID}\"/g" "$2"/EFI/BOOT/themes/OpenMandriva/theme.txt
	XORRISO_OPTIONS="$XORRISO_OPTIONS --efi-boot boot/grub/efiboot.img -efi-boot-part --efi-boot-image"
    fi

    $SUDO rm -rf $GRUB_IMG

}

# Usage: setupSysLinux /target/dir
# Sets up syslinux to boot /target/dir
setupSyslinux() {
    echo "Starting syslinux setup."
    # default options for xorriso
    XORRISO_OPTIONS=" -b boot/syslinux/isolinux.bin -no-emul-boot -boot-info-table -boot-load-size 4 -boot-info-table -c boot/syslinux/boot.cat"

    $SUDO mkdir -p "$2"/boot/syslinux "$2"/boot/syslinux/hdt
    $SUDO chmod 1777 "$2"/boot/syslinux
    # install syslinux programs
    echo "Installing syslinux programs."

    # it is important to detect syslinux version
    syslinux_ver=`chroot "$1" rpm -qa syslinux --queryformat '%{VERSION}'`
    if (( ${syslinux_ver%%.*} >= 6 )); then
	echo "Detected syslinux version 6 or greater"
	syslinux_libs="isolinux.bin libcom32.c32 libutil.c32 libmenu.c32 libgpl.c32 menu.c32 gfxboot.c32 vesamenu.c32 hdt.c32 poweroff.c32 chain.c32 ldlinux.c32 isohdpfx.bin memdisk"
    else
	echo "Detected syslinux version older than 6"
	syslinux_libs="isolinux.bin vesamenu.c32 hdt.c32 poweroff.com chain.c32 isohdpfx.bin memdisk"
    fi
    for i in $syslinux_libs ; do
	if [ ! -f "$1"/usr/lib/syslinux/$i ]; then
	    echo "$i does not exists. Exiting."
	    errorCatch
	fi
	$SUDO cp -f "$1"/usr/lib/syslinux/$i "$2"/boot/syslinux ;
    done

    # install pci.ids
    $SUDO gzip -c -9 "$1"/usr/share/pci.ids > "$2"/boot/syslinux/hdt/pciids.gz
    $SUDO gzip -c -9 "$1"/lib/modules/*/modules.alias > "$2"/boot/syslinux/hdt/modalias.gz

    $SUDO mkdir -p "$2"/LiveOS

    echo "Installing liveinitrd inside syslinux"
    if [ -e "$1"/boot/vmlinuz-$BOOT_KERNEL_ISO ] && [ -e "$1"/boot/liveinitrd.img ]; then
	$SUDO cp -a "$1"/boot/vmlinuz-$BOOT_KERNEL_ISO "$2"/boot/syslinux/vmlinuz0
	$SUDO cp -a "$1"/boot/liveinitrd.img "$2"/boot/syslinux/liveinitrd.img
    else
	echo "vmlinuz or liveinitrd does not exists. Exiting."
	errorCatch
    fi

    if [ ! -f "$2"/boot/syslinux/liveinitrd.img ]; then
	echo "Missing /boot/syslinux/liveinitrd.img. Exiting."
	errorCatch
    else
	$SUDO rm -rf "$1"/boot/liveinitrd.img
    fi

    echo "Copy various syslinux settings"
    # copy boot menu background
    if [ -e "$1"/usr/share/mdk/backgrounds/default.png ]; then
	# convert is needed to meet syslinux specifications
	$SUDO convert -depth 16 -resize 640x480 "$1"/usr/share/mdk/backgrounds/default.png "$2"/boot/syslinux/background.png
    else
	echo "Could not find default.png in iso chroot, using default background for syslinux"
	$SUDO cp -rfT $WORKDIR/extraconfig/syslinux/background.png "$2"/boot/syslinux/background.png
    fi

    # copy memtest
    $SUDO cp -rfT $WORKDIR/extraconfig/memtest "$2"/boot/syslinux/memtest
    $SUDO chmod +x "$2"/boot/syslinux/memtest
    # copy SuperGrub iso
    $SUDO cp -rfT $WORKDIR/extraconfig/super_grub2_disk_i386_pc_2.00s2.iso "$2"/boot/syslinux/sgb.iso

    # UEFI support
    if [ -f "$1"/boot/efi/EFI/openmandriva/grub.efi ]; then
	export UEFI=1
	$SUDO mkdir -m 0755 -p "$2"/EFI/BOOT "$2"/EFI/BOOT/fonts "$2"/EFI/BOOT/themes "$2"/EFI/BOOT/locale "$2"/boot/grub2
	$SUDO cp -f "$1"/boot/efi/EFI/openmandriva/grub.efi "$2"/EFI/BOOT/grub.efi

	# For bootable iso's we need grub.efi as BOOTX64.efi or BOOTIA32.efi
	if [ "$EXTARCH" = "x86_64" ]; then
	    $SUDO cp -f "$1"/boot/efi/EFI/openmandriva/grub.efi "$2"/EFI/BOOT/BOOTX64.efi
	else
	    $SUDO cp -f "$1"/boot/efi/EFI/openmandriva/grub.efi "$2"/EFI/BOOT/BOOTIA32.efi
	    $SUDO cp -f $WORKDIR/EFI/grub.cfg "$2"/EFI/BOOT/BOOTIA32.cfg
	fi

	$SUDO cp -f $WORKDIR/EFI/grub.cfg "$2"/boot/grub2/grub.cfg
	$SUDO cp -f $WORKDIR/EFI/grub.cfg "$2"/EFI/BOOT/grub.cfg
	$SUDO cp -a -f "$1"/boot/grub2/themes "$2"/EFI/BOOT/
	$SUDO cp -a -f "$1"/boot/grub2/locale "$2"/EFI/BOOT/
	$SUDO sed -i -e "s/%GRUB_UUID%/${GRUB_UUID}/g" "$2"/boot/grub2/*.cfg
	$SUDO sed -i -e "s/%GRUB_UUID%/${GRUB_UUID}/g" "$2"/boot/grub2/grub2-bios*.cfg
	$SUDO sed -i -e "s/%GRUB_UUID%/${GRUB_UUID}/g" "$2"/EFI/BOOT/*.cfg

	sed -i -e "s/title-text.*/title-text: \"Welcome to OpenMandriva Lx $VERSION ${EXTARCH} ${TYPE} BUILD ID: ${BUILD_ID}\"/g" "$2"/EFI/BOOT/themes/OpenMandriva/theme.txt
	# (tpg) looks like fonts are in themes dir for 2015.0
	# need to adapt this for n < 2015.0
	#for i in dejavu_sans_bold_14.pf2 dejavu_sans_mono_11.pf2 terminal_font_11.pf2 unicode.pf2; do
	#	$SUDO cp -f "$1"/boot/grub2/themes/*/$i "$2"/EFI/BOOT/fonts/$i
	#done
	# EFI options for xorriso
	XORRISO_OPTIONS="$XORRISO_OPTIONS -isohybrid-mbr "$2"/boot/syslinux/isohdpfx.bin -partition_offset 16  -eltorito-alt-boot -e boot/syslinux/efiboot.img -no-emul-boot -isohybrid-gpt-basdat -append_partition 2 0xef $ISOROOTNAME/boot/syslinux/efiboot.img"
    fi

    echo "Create syslinux menu"
    # kernel/initrd filenames referenced below are the ISO9660 names.
    # syslinux doesn't support Rock Ridge.
    $SUDO cp -rfT $WORKDIR/extraconfig/syslinux/syslinux.cfg "$2"/boot/syslinux/syslinux.cfg

    # adjust syslinux config
    sed -i -e "s/%VERSION%/$VERSION/g" -e "s/%EXTARCH%/${EXTARCH}/g" -e "s/%TYPE%/${TYPE}/g" -e "s/%BUILD_ID%/BUILD ID: ${BUILD_ID}/g" -e "s/%LABEL%/${LABEL}/g" "$2"/boot/syslinux/syslinux.cfg

    # workaround for flickering whitebox when booting ISO
    if (( ${syslinux_ver%%.*} < 6 )); then
	sed -i -e "s/vga=current/vga=784/g" "$2"/boot/syslinux/syslinux.cfg
    fi

    $SUDO chmod 0755 "$2"/boot/syslinux

    echo "syslinux setup completed."
}

# Usage: setupBootloader
# Sets up grub2/syslinux to boot /target/dir
setupBootloader() {

    setupGrub2 "$CHROOTNAME" "$ISOROOTNAME"

}

setupISOenv() {

    # clear root password
    $SUDO chroot "$CHROOTNAME" /usr/bin/passwd -f -d root

    # set up default timezone
    echo "Setting default timezone"
    $SUDO ln -sf /usr/share/zoneinfo/Universal "$CHROOTNAME"/etc/localtime

    # try harder with systemd-nspawn
    # version 215 and never has then --share-system option
#	if (( `rpm -qa systemd --queryformat '%{VERSION} \n'` >= "215" )); then
#	    $SUDO systemd-nspawn --share-system -D "$CHROOTNAME" /usr/bin/timedatectl set-timezone UTC
#	    # set default locale
#	    echo "Setting default localization"
#	    $SUDO systemd-nspawn --share-system -D "$CHROOTNAME" /usr/bin/localectl set-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8:en_US:en
#	else
#	    echo "systemd-nspawn does not exists."
#	fi

	# create /etc/minsysreqs
    echo "Creating /etc/minsysreqs"

    if [ "${TYPE,,}" = "minimal" ]; then
	echo "ram = 512" >> "$CHROOTNAME"/etc/minsysreqs
	echo "hdd = 5" >> "$CHROOTNAME"/etc/minsysreqs
    elif [ "$EXTARCH" = "x86_64" ]; then
	echo "ram = 1536" >> "$CHROOTNAME"/etc/minsysreqs
	echo "hdd = 10" >> "$CHROOTNAME"/etc/minsysreqs
    else
	echo "ram = 1024" >> "$CHROOTNAME"/etc/minsysreqs
	echo "hdd = 10" >> "$CHROOTNAME"/etc/minsysreqs
    fi

    # count imagesize and put in in /etc/minsysreqs
    $SUDO echo "imagesize = $(du -a -x -b -P "$CHROOTNAME" | tail -1 | awk '{print $1}')" >> "$CHROOTNAME"/etc/minsysreqs

    # set up displaymanager
    if [ "${TYPE,,}" != "minimal" ] && [ ${DISPLAYMANAGER,,} != "none" ]; then
	$SUDO ln -sf /lib/systemd/system/${DISPLAYMANAGER,,}.service "$CHROOTNAME"/etc/systemd/system/display-manager.service 2> /dev/null || :

	# Set reasonable defaults
	if  [ -e "$CHROOTNAME"/etc/sysconfig/desktop ]; then
	    $SUDO rm -rf "$CHROOTNAME"/etc/sysconfig/desktop
	fi

    # create very important desktop file
    cat >"$CHROOTNAME"/etc/sysconfig/desktop <<EOF
DISPLAYMANAGER=$DISPLAYMANAGER
DESKTOP=$TYPE
EOF

    fi

    # copy some extra config files
    $SUDO cp -rfT $WORKDIR/extraconfig/etc "$CHROOTNAME"/etc/
    $SUDO cp -rfT $WORKDIR/extraconfig/usr "$CHROOTNAME"/usr/

    # set up live user
    live_user=live
    echo "Setting up user ${live_user}"
    $SUDO chroot "$CHROOTNAME" /usr/sbin/adduser -G wheel ${live_user}
    $SUDO chroot "$CHROOTNAME" /usr/bin/passwd -d ${live_user}
    $SUDO chroot "$CHROOTNAME" /bin/mkdir -p /home/${live_user}
    $SUDO chroot "$CHROOTNAME" /bin/cp -rfT /etc/skel /home/${live_user}/
    $SUDO chroot "$CHROOTNAME" /bin/mkdir /home/${live_user}/Desktop
    $SUDO cp -rfT $WORKDIR/extraconfig/etc/skel "$CHROOTNAME"/home/${live_user}/
    $SUDO chroot "$CHROOTNAME" /bin/mkdir -p /home/${live_user}/.cache
    $SUDO chroot "$CHROOTNAME" /bin/chown -R ${live_user}:${live_user} /home/${live_user}
    $SUDO chroot "$CHROOTNAME" /bin/chown -R ${live_user}:${live_user} /home/${live_user}/Desktop
    $SUDO chroot "$CHROOTNAME" /bin/chown -R ${live_user}:${live_user} /home/${live_user}/.cache
    $SUDO chroot "$CHROOTNAME" /bin/chmod -R 0777 /home/${live_user}/.local

    # KDE4 related settings
    if [ "${TYPE,,}" = "kde4" ] || [ "${TYPE,,}" = "plasma" ]; then
	$SUDO mkdir -p "$CHROOTNAME"/home/$live_user/.kde4/env
	echo "export KDEVARTMP=/tmp" > "$CHROOTNAME"/home/${live_user}/.kde4/env/00-live.sh
	echo "export KDETMP=/tmp" >> "$CHROOTNAME"/home/${live_user}/.kde4/env/00-live.sh
	# disable baloo in live session
	$SUDO mkdir -p "$CHROOTNAME"/home/${live_user}/.kde4/share/config
	cat >"$CHROOTNAME"/home/${live_user}/.kde4/share/config/baloofilerc << EOF
[Basic Settings]
Indexing-Enabled=false
EOF
	$SUDO chroot "$CHROOTNAME" chmod -R 0777 /home/${live_user}/.kde4
	$SUDO chroot "$CHROOTNAME" /bin/chown -R ${live_user}:${live_user} /home/${live_user}/.kde4
    else
	$SUDO rm -rf "$CHROOTNAME"/home/$live_user}/.kde4
    fi

    # enable DM autologin
    if [ "${TYPE,,}" != "minimal" ]; then
	case ${DISPLAYMANAGER,,} in
		"kdm")
		    $SUDO chroot "$CHROOTNAME" sed -i -e 's/.*AutoLoginEnable.*/AutoLoginEnable=True/g' -e 's/.*AutoLoginUser.*/AutoLoginUser=live/g' /usr/share/config/kdm/kdmrc
		    ;;
		"sddm")
		    $SUDO chroot "$CHROOTNAME" sed -i -e "s/^Session=.*/Session=${TYPE,,}.desktop/g" -e 's/^User=.*/User=live/g' /etc/sddm.conf

		    ;;
		"gdm")
		    $SUDO chroot "$CHROOTNAME" sed -i -e "s/^AutomaticLoginEnable.*/AutomaticLoginEnable=True/g" -e 's/^AutomaticLogin.*/AutomaticLogin=live/g' /etc/X11/gdm/custom.conf
		    ;;
		*)
		    echo "${DISPLAYMANAGER,,} is not supported, autologin feature will be not enabled"
	esac
    fi

    $SUDO pushd "$CHROOTNAME"/etc/sysconfig/network-scripts
    for iface in eth0 wlan0; do
	cat > ifcfg-$iface << EOF
DEVICE=$iface
ONBOOT=yes
NM_CONTROLLED=yes
EOF
    done
    $SUDO popd

    echo "Starting services setup."
    # enable services
    SERVICES_ENABLE=(systemd-networkd systemd-networkd.socket systemd-resolved systemd-timesyncd systemd-timedated NetworkManager sshd.socket cups.path cups.socket cups-lpd.socket cups cups-browsed acpid alsa atd avahi-daemon irqbalance netfs rpcbind.socket udev-post mandrake_everytime crond accounts-daemon tuned firewalld)

    for i in "${SERVICES_ENABLE[@]}"; do
	if [[ $i  =~ ^.*socket$|^.*path$|^.*target$|^.*timer$ ]]; then
	    if [ -e "$CHROOTNAME"/lib/systemd/system/$i ]; then
		echo "Enabling $i"
		ln -sf /lib/systemd/system/$i "$CHROOTNAME"/etc/systemd/system/multi-user.target.wants/$i
	    else
		echo "Special service $i does not exist. Skipping."
	    fi
	elif [[ ! $i  =~ ^.*socket$|^.*path$|^.*target$|^.*timer$ ]]; then
	    if [ -e "$CHROOTNAME"/lib/systemd/system/$i.service ]; then
		echo "Enabling $i.service"
		ln -sf /lib/systemd/system/$i.service "$CHROOTNAME"/etc/systemd/system/multi-user.target.wants/$i.service
	    else
		echo "Service $i does not exist. Skipping."
	    fi

	else
	    echo "Wrong service match."
	fi
    done

    # disable services
    SERVICES_DISABLE=(pptp pppoe ntpd iptables ip6tables shorewall nfs-server mysqld abrtd mysql postfix NetworkManager-wait-online chronyd)

    for i in "${SERVICES_DISABLE[@]}"; do
	if [[ $i  =~ ^.*socket$|^.*path$|^.*target$|^.*timer$ ]]; then
	    if [ -e "$CHROOTNAME"/lib/systemd/system/$i ]; then
		echo "Disabling $i"
		$SUDO rm -rf "$CHROOTNAME"/etc/systemd/system/multi-user.target.wants/$i
	    else
		echo "Special service $i does not exist. Skipping."
	    fi
	elif [[ ! $i  =~ ^.*socket$|^.*path$|^.*target$|^.*timer$ ]]; then
	    if [ -e "$CHROOTNAME"/lib/systemd/system/$i.service ]; then
		echo "Disabling $i.service"
		$SUDO rm -rf "$CHROOTNAME"/etc/systemd/system/multi-user.target.wants/$i.service
	    else
		echo "Service $i does not exist. Skipping."
	    fi

	else
	    echo "Wrong service match."
	fi
    done

    # Calamares installer
#    if [ -e "$CHROOTNAME"/etc/calamares/modules/unpackfs.conf ]; then
#	echo "Updating calamares settings."
	# update patch to squashfs
#	$SUDO sed -i -e "s#source:.*#source: "/media/$LABEL/LiveOS/squashfs.img"#" "$CHROOTNAME"/etc/calamares/modules/unpackfs.conf
#    fi

    #remove rpm db files which may not match the non-chroot environment
    $SUDO chroot "$CHROOTNAME" rm -f /var/lib/rpm/__db.*

    if [ -z "$NOCLEAN" ]; then
	# add urpmi medias inside chroot
        echo "Removing old urpmi repositories."
	$SUDO urpmi.removemedia -a --urpmi-root "$CHROOTNAME"

        echo "Adding new urpmi repositories."
	if [ "${TREE,,}" = "cooker" ]; then
	    MIRRORLIST="http://downloads.openmandriva.org/mirrors/cooker.$EXTARCH.list"

	    $SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" --wget --no-md5sum --mirrorlist "$MIRRORLIST" 'Main' 'media/main/release'
	    $SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" --wget --no-md5sum --mirrorlist "$MIRRORLIST" 'Contrib' 'media/contrib/release'
	    # this one is needed to grab firmwares
	    $SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" --wget --no-md5sum --mirrorlist "$MIRRORLIST" 'Non-free' 'media/non-free/release'
	else
	    # use hack for our mirrorlist url
	    if [[ ${TREE,,} =~ ^openmandriva* ]]; then
		MIRRORLIST="http://downloads.openmandriva.org/mirrors/${TREE/openmandriva/openmandriva.}.$EXTARCH.list"
	    else
		MIRRORLIST="http://downloads.openmandriva.org/mirrors/$TREE.$EXTARCH.list"
	    fi
	    echo "Using $MIRRORLIST"
	    $SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" --wget --no-md5sum --distrib --mirrorlist $MIRRORLIST
	fi

	# add 32-bit medias only for x86_64 arch
	if [ "$EXTARCH" = "x86_64" ]; then
	    echo "Adding 32-bit media repository."

	    # use previous MIRRORLIST declaration but with i586 arch in link name
	    MIRRORLIST="`echo $MIRRORLIST | sed -e "s/x86_64/i586/g"`"
	    $SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" --wget --no-md5sum --mirrorlist "$MIRRORLIST" 'Main32' 'media/main/release'

	    if [ "${TREE,,}" != "cooker" ]; then
		$SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" --wget --no-md5sum --mirrorlist "$MIRRORLIST" 'Main32Updates' 'media/main/updates'

		if [[ $? != 0 ]]; then
		    echo "Adding urpmi 32-bit media FAILED. Exiting";
		    errorCatch
		fi
	    fi

	else
	    echo "urpmi 32-bit media repository not needed"
	fi

	# update urpmi medias
	echo "Updating urpmi repositories"
	$SUDO urpmi.update --urpmi-root "$CHROOTNAME" -a -ff --wget --force-key
    fi # noclean

    # get back to real /etc/resolv.conf
    $SUDO rm -f "$CHROOTNAME"/etc/resolv.conf
    if [ "`cat $CHROOTNAME/etc/release | grep -o 2014.0`" == "2014.0" ]; then
	$SUDO ln -sf /run/resolvconf/resolv.conf "$CHROOTNAME"/etc/resolv.conf
    else
	$SUDO ln -sf /run/systemd/resolve/resolv.conf "$CHROOTNAME"/etc/resolv.conf
    fi

    # ldetect stuff
    if [ -x "$CHROOTNAME"/usr/sbin/update-ldetect-lst ]; then
	$SUDO chroot "$CHROOTNAME" /usr/sbin/update-ldetect-lst
    fi

    # fontconfig cache
    if [ -x "$CHROOTNAME"/usr/bin/fc-cache ]; then
	$SUDO chroot "$CHROOTNAME" fc-cache -s -r
    fi

    # rebuild man-db
    if [ -x "$CHROOTNAME"/usr/bin/mandb ]; then
    	$SUDO chroot "$CHROOTNAME" /usr/bin/mandb --quiet
    fi

    # rebuild linker cache
    $SUDO chroot "$CHROOTNAME" /sbin/ldconfig -X

    # remove rpm db files to save some space
    $SUDO chroot "$CHROOTNAME" rm -f /var/lib/rpm/__db.*
}

createSquash() {
    echo "Starting squashfs image build."
	# Before we do anything check if we are a local build
    if [ -n "$ABF" ]; then
	# We so make sure that nothing is mounted on the chroots /run/os-prober/dev/ directory.
	# If mounts exist mksquashfs will try to build a squashfs.img with contents of all  mounted drives 
	# It's likely that the img will be written to one of the mounted drives so it's unlikely 
	# that there will be enough diskspace to complete the operation.
	if [ -f "$ISOCHROOTNAME"/run/os-prober/dev/* ]; then
	    $SUDO umount -l `echo "$ISOCHROOTNAME"/run/os-prober/dev/*`
	    if [ -f "$ISOCHROOTNAME"/run/os-prober/dev/* ]; then
		echo "Cannot unount os-prober mounts aborting."
		errorCatch
	    fi
	fi
    fi

    if [ -f "$ISOROOTNAME"/LiveOS/squashfs.img ]; then
	$SUDO rm -rf "$ISOROOTNAME"/LiveOS/squashfs.img
    fi

    mkdir -p "$ISOROOTNAME"/LiveOS
    # unmout all stuff inside CHROOT to build squashfs image
    umountAll "$CHROOTNAME"

    $SUDO mksquashfs "$CHROOTNAME" "$ISOROOTNAME"/LiveOS/squashfs.img -comp xz -no-progress -no-recovery -b 16384

    if [ ! -f  "$ISOROOTNAME"/LiveOS/squashfs.img ]; then
	echo "Failed to create squashfs. Exiting."
	errorCatch
    fi

}

# Usage: buildIso filename.iso rootdir
# Builds an ISO file from the files in rootdir
buildIso() {
    echo "Starting ISO build."

    if [ -n "$ABF" ]; then
	ISOFILE="$WORKDIR/$PRODUCT_ID.$EXTARCH.iso"
    elif [ -z "$OUTPUTDIR" ]; then
	ISOFILE="/home/$OLDUSER/$PRODUCT_ID.$EXTARCH.iso"
    else
	ISOFILE="$OUTPUTDIR/$PRODUCT_ID.$EXTARCH.iso"
    fi

    if [ ! -x /usr/bin/xorriso ]; then
	echo "xorriso does not exists. Exiting."
	errorCatch
    fi

    # Before starting to build remove the old iso. xorriso is much slower to create an iso.
    # if it is overwriting an earlier copy. Also it's not clear whether this affects the.
    # contents or structure of the iso (see --append-partition in the man page)
    # Either way building the iso is 30 seconds quicker (for a 1G iso) if the old one is deleted.
    echo "Removing old iso."
    if [ -z "$ABF" ] && [ -n "$ISOFILE" ]; then
	$SUDO rm -rf "$ISOFILE"
    fi
    echo "Building ISO with options ${XORRISO_OPTIONS}"

    $SUDO xorriso -as mkisofs -R -r -J -joliet-long -cache-inodes \
	-graft-points -iso-level 3 -full-iso9660-filenames \
	--modification-date=${ISO_DATE} \
	-omit-version-number -disable-deep-relocation \
	${XORRISO_OPTIONS} \
	-publisher "OpenMandriva Association" \
	-preparer "OpenMandriva Association" \
	-volid "$LABEL" -o "$ISOFILE" "$ISOROOTNAME"

    if [ ! -f "$ISOFILE" ]; then
	echo "Failed build iso image. Exiting"
	errorCatch
    fi

    echo "ISO build completed."
}

postBuild() {

    if [ ! -f $ISOFILE ]; then
	umountAll "$CHROOTNAME"
	errorCatch
    fi

    if [ -n "$ABF" ]; then
    	# We're running in ABF adjust to its directory structure
	# count checksums
	echo "Genrating ISO checksums."
	pushd $WORKDIR
	    md5sum $PRODUCT_ID.$EXTARCH.iso > $PRODUCT_ID.$EXTARCH.iso.md5sum
	    sha1sum $PRODUCT_ID.$EXTARCH.iso > $PRODUCT_ID.$EXTARCH.iso.sha1sum
	popd

	mkdir -p /home/vagrant/results /home/vagrant/archives
	mv $WORKDIR/*.iso* /home/vagrant/results/
    fi

    # clean chroot
    umountAll "$CHROOTNAME"
}


# START ISO BUILD

showInfo
updateSystem
getPkgList
createChroot
createInitrd
setupBootloader
createUEFI
setupISOenv
createSquash
buildIso
postBuild

#END

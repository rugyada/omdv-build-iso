#!/bin/bash
# OpenMandriva Association 2012
# Original author: Bernhard Rosenkraenzer <bero@lindev.ch>
# Modified on 2014 by: Tomasz Pawe³ Gajc <tpgxyz@gmail.com>
# Modified on 2015 by: Tomasz Pawe³ Gajc <tpgxyz@gmail.com>
# Modified on 2015 by: Colin Close <itchka@compuserve.com>
# Modified on 2015 by: Crispin Boylan <cris@beebgames.com>
# Modified on 2016 by: Tomasz Pawe³½ Gajc <tpgxyz@gmail.com>
# Modified on 2016 by: Colin Close <itchka@compuserve.com>
# Modified on 2017 by: Colin Close <itchka@compuserve.com>
# Mofified 0n 2018 by: Colin Close <itchka@compuserve.com>

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

# This tool is specified to build OpenMandriva Lx distribution ISO


# use only allowed arguments
# TODO:
# Add user controlled variable for setting number of failures tolerated

# DONE Add choice of xargs or parallel for ABF builds
# DONE buffer standards out so that the output of urpmi can be monitored for failed dependencies and then extracted and placed in a separate log.


main() {

# This function which starts at the top of the file is executed first from the end of file 
# to ensure that all functions are read before the body of the script is run.
# All global variables need to be inside the curly braces of this function.

if [ $# -ge 1 ]; then
    for k in "$@"; do
	case "$k" in
		--arch=*)
        	    EXTARCH=${k#*=}
        	    shift
        	    ;;
#FIXME?
		--tree=*)
		    TREE=${k#*=}
			case "$TREE" in
			    cooker)
				TREE=cooker
            		    ;;
            		    lx3)
            			TREE=3.0
            		    ;;
            		    openmandriva2014.0)
            			TREE=openmandriva2014.0
            		    ;;
            		    *)
            		    TREE="$TREE"
            		    ;;
        		esac
			shift
        		;;
		--version=*)
        	    VERSION=${k#*=}
        	    if [[ "${VERSION,,}" == "cooker" ]]
        	    then
			    VERSION="$(date +%Y.0)"
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
				user)
				TYPE=my.add
				;;
			    *)
				printf "%s\n" "$TYPE is not supported."
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
        	    WORK=${k#*=}
        	    # Expand the tilde
        	    WORKDIR=${WORK/#\~/$HOME}
        	    shift
        	    ;;
        	--outputdir=*)
        	    OUTPUT=${k#*=}
        	    # Expand the tilde
        	    OUTPUTDIR=${OUTPUT/#\~/$HOME}
        	    shift
        	    ;;
    		--debug)
        	    DEBUG=debug
        	    shift
        	    ;;
            --urpmi-debug)
                URPMI_DEBUG=--debug
                shift
                ;;
        	--noclean)
        	    NOCLEAN=noclean
        	    shift
        	    ;;
            --rebuild)
                   REBUILD=rebuild
                   shift
                   ;;
             --quicken)
                   QUICKEN=squashfs
                   shift
                   ;;
             --compressor=*)
            	   COMPTYPE=${k#*=}
            	   shift
            	   ;;
             --keep)
                   KEEP=keep
                   shift
                   ;;
             --testrepo)
            	    TESTREPO=testrepo
            	    shift
                   ;;
             --parallel)
            	    PLLL=plll
            	    shift
                   ;;
             --maxerrors=*)
                    MAXERRORS=${k#*=}
                    shift
                   ;;
             --devmode)
                    DEVMODE=devmode
                    shift
                    ;;
             --auto-update)
		    AUTO_UPDATE=1
		    shift
		    ;;
             --enable-skip-list)
                    ENSKPLST=enskplst #prolly should be a symlink
                    shift
                    ;;
             --enable-skip-list)
                    USRBUILD=usrbuild #allow fresh build without destroying user files
                    shift
                    ;;
             --help)
        	    usage_help
        	    shift
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
# The abf isobuilder docker instance is created with a single working directory /home/omv/iso_builder. This directory must not be deleted as it contains important (but hidden) config files.
# A support directory /home/omv/docker-iso-worker is also created this should not be touched.
# When an iso build request is generated from ABF the script commandline along with the data from the git repo for the named branch of the script is loaded into the the /home/omv/iso_builder directory and the script executed from that directory. If the build completes without error a directory /home/omv/iso_builder/results is created and the completed iso along with it's md5 and sha1 checksums are moved to it. These files are eventually uploaded to abf for linking and display on the build results webpage. If the results are placed anywhere else they are not displayed. 

SUDOVAR=""EXTARCH="$EXTARCH "TREE="$TREE "VERSION="$VERSION "RELEASE_ID="$RELEASE_ID "TYPE="$TYPE "DISPLAYMANAGER="$DISPLAYMANAGER "DEBUG="$DEBUG \
"NOCLEAN="$NOCLEAN "REBUILD="$REBUILD "WORKDIR="$WORKDIR "OUTPUTDIR="$OUTPUTDIR "ISO_VER="$ISO_VER "ABF="$ABF "QUICKEN="$QUICKEN "COMPTYPE="$COMPTYPE \
"KEEP="$KEEP "TESTREPO="$TESTREPO "AUTO_UPDATE="$AUTO_UPDATE "DEVMODE="$DEVMODE "ENSKPLST="$ENSKPLST "USRBUILD="$USRBUILD "PARALLEL="$PARALLEL "MAXERRORS="$MAXERRORS"
# run only when root

if [ "$(id -u)" != "0" ]; then
    # We need to be root for umount and friends to work...
    # NOTE the following command will only work on OMDV for the first registered user
    # this user is a member of the wheel group and has root privelidges
    exec sudo -E `echo ${SUDOVAR}` $0 "$@"
    printf "%s\n" "-> Run me as root."
    exit 1
fi
# Set the local build prefix
if [ -d /home/omv ] && [ -d '/home/omv/docker-iso-worker' ]; then 
WHO=omv
else
WHO="$SUDO_USER"
UHOME=/home/"$WHO"
fi

allowedOptions
setWorkdir

# default definitions
DIST=omdv
[ -z "$EXTARCH" ] && EXTARCH="$(uname -m)"
[ -z "${TREE}" ] && TREE=cooker
[ -z "${VERSION}" ] && VERSION="$(date +%Y.0)"
[ -z "${RELEASE_ID}" ] && RELEASE_ID=alpha
[ -z "${COMPTYPE}" ] && COMPTYPE=zstd
if [[ ( "$IN_ABF" == "1"  &&  -n "$DEBUG" )  ||  "$IN_ABF" == "0" ]]; then
    if [ -z "$NOCLEAN" ]; then
    [ -z "${BUILD_ID}" ] && BUILD_ID=$(($RANDOM%9999+1000))
    # The build_id gets written to file when the use makes the first change
    else
    #The BUILD_ID has already been saved. Used to identify user diffs.
    BUILD_ID=$(cat "$WORKDIR"/sessrec/.build_id)
    fi
fi

# always build free ISO
FREE=1
LOGDIR="."

# User mode allows three modes of operation.
# All user modes rely on the script being run with no user options to generate  the initial chroot.
# The options are:-
# --noclean Where the chroot (once generated) is reused
# --rebuild. Where the chroot/BASE is rebuilt from the initial rpm downloads
# Run without either option and with --workdir pointing to the chroot 
# the script will delete the existing chroot and create a new one.

# For all modes any changes made to the pkg lists are implemented and recorded
# User mode also generates a series of diffs as a record of the multiple sessions.
# The --keep option allow these to be retained for subsequent sessions

#if [[ "$IN_ABF" == "0" && -n "$KEEP" && -d "$WORKDIR/sessrec" ]]; then
#    $SUDO mv "$WORKDIR/sessrec" "$UHOME"
#    printf "%s\n" "-> Retaining your session records"
#fi


# MIGHT BE A GOOD IDEA TO CREATE A FUNCTION "SAVE DATA" TO MAKE BELOW MOR MANAGABLE.

if [[ "$IN_ABF" == "1" && -n "$DEBUG" && "$WHO" != "omv" && -z "$NOCLEAN" ]]; then
RemkWorkDir
elif [[ "$IN_ABF" == "0" && -z "$NOCLEAN" && -z "$REBUILD" && -d "$WORKDIR" ]]; then
    if [ -n "$KEEP" ]; then
    SaveDaTa
    RestoreDaTa
    # RestoreDaTa also cleans and recreates the $WORKDIR
    else
     printf "%s\n" "-> No base chroot exists...creating one"
     RemkWorkDir
    fi
fi

if [[ "$IN_ABF" == "0" && -n "$REBUILD" && -d "$WORKDIR" ]]; then
    if [ -n "$KEEP" ]; then
    SaveDaTa
    RestoreDaTa    
    fi
#Remake needed directories
fi
if [ ! -d "$WORKDIR" ]; then
  printf "%s\n" "-> Error the $WORKDIR does not exist there is nothing to rebuild." \
   "-> You must run  your command with the --noclean option set to create something to rebuild."
  exit 1
fi

if [[ -n "$NOCLEAN" && -d "$WORKDIR" ]]; then #if NOCLEAN option selected then retain the chroot.
	if [ -d "$WORKDIR/sessrec" ]; then
        printf "%s\n" "-> You have chosen not to clean the base installation" \
        "If your build chroot becomes corrupted you may want"\
        "to take advantage of the 'rebuild' option to delete the corrupted files"\
        "and build a new base installation." \
        "This will be faster than dowloading the rpm packages again"
    fi
    # Note need to clean out grub uuid files here and maybe others
fi

# Assign the config build list
if [ "$TYPE" == "my.add" ]; then
FILELISTS="$WORKDIR/iso-pkg-lists-${TREE,,}/${TYPE,,}"
printf "%s\n" " " "-> You are creating a user build" \
"This build will use the the omdv_minimal_iso.lst to create a basic iso" \
"Additional packages or files to be included may be added to the file my.add" \
"Packages or files that you wish to be removed may be added to the file my.rmv"
userISONme
else
FILELISTS="$WORKDIR/iso-pkg-lists-${TREE,,}/${DIST,,}-${TYPE,,}.lst"
fi

# Create the ISO directory
$SUDO mkdir -m 0755 -p "$ISOROOTNAME"/EFI/BOOT
# and the grub diectory
$SUDO mkdir -m 0755 -p "$ISOROOTNAME"/boot/grub

# START ISO BUILD

mkISOLabel
showInfo
updateSystem
getPkgList
localMd5Change #Calls doDiff
createChroot
createInitrd
createMemDisk
createUEFI
setupGrub2
setupISOenv
createSquash
buildIso
postBuild
FilterLogs
#END
}

########################
#   Start functions    #
########################

SaveDaTa() {
printf %s\n "Saving config data"
if [ -n "$KEEP" ]; then
mv "$WORKDIR/iso-pkg-lists-${TREE,,}" "$UHOME/iso-pkg-lists-${TREE,,}"
mv "$WORKDIR/sessrec" "$UHOME/sessrec"
fi
mv "$WORKDIR/dracut" "$UHOME/dracut"
mv "$WORKDIR/grub2" "$UHOME/grub2"
mv "$WORKDIR/boot" "$UHOME/boot"
if [ -n "$REBUILD" ]; then
printf %s\n "-> Saving rpms for rebuild"
$SUDO mv "$CHROOTNAME/var/cache/urpmi/rpms" "$UHOME/RPMS"
fi
}

RestoreDaTa() {
printf %s\n  "->    Cleaning WORKDIR"
# Re-creates the WORKDIR and populates it with saved data
# In the case of a rebuild the $CHRROTNAME dir is recreated and the saved rpm cache is restored to it..
$SUDO rm -rf "$WORKDIR"
$SUDO mkdir -p "$WORKDIR"
if [ -n "$KEEP" ]; then
printf %s\n "-> Restoring package lists and the session records"
mv "$UHOME/iso-pkg-lists-${TREE,,}" "$WORKDIR/iso-pkg-lists-${TREE,,}"
mv "$UHOME/sessrec" "$WORKDIR/sessrec"
fi
mv "$UHOME/dracut" "$WORKDIR/dracut"
mv "$UHOME/grub2" "$WORKDIR/grub2"
mv "$UHOME/boot" "$WORKDIR/boot"
if [ -n "$REBUILD" ]; then
printf %s\n "-> Restoring rpms for new build"
#Remake needed directories
$SUDO mkdir -p "$CHROOTNAME/proc" "$CHROOTNAME/sys" "$CHROOTNAME/dev/pts"
$SUDO mkdir -p "$CHROOTNAME/var/lib/rpm" #For the rpmdb
$SUDO mkdir -p "$CHROOTNAME/var/cache/urpmi"
$SUDO mv "$UHOME/RPMS" "$CHROOTNAME/var/cache/urpmi/rpms"
fi
$SUDO touch "$WORKDIR/.new"
}

RemkWorkDir() {
echo "Remake dirs"
$SUDO rm -rf "$WORKDIR"
$SUDO mkdir -p "$WORKDIR"
if [ "$IN_ABF" == "0" ]; then
$SUDO touch "$WORKDIR/.new"
fi
}


setWorkdir() {
# Set the $WORKDIR
# If ABF=1 then $WORKDIR codes to /bin on a local system so if you try and test with ABF=1 /bin is rm -rf ed.
# To avoid this and to allow testing use the --debug flag to indicate that the default ABF $WORKDIR path should not be used
# To ensure that the WORKDIR does not get set to /usr/bin if the script is started we check the WORKDIR path used by abf and 
# To allow testing the default ABF WORKDIR is set to a different path if the DEBUG option is set and the user is non-root.

if [[ "$IN_ABF" == "1"  &&  ! -d '/home/omv/docker-iso-worker'  &&  -z "$DEBUG" ]]; then
printf "%s\n" "-> DO NOT RUN THIS SCRIPT WITH ABF=1 ON A LOCAL SYSTEM WITHOUT SETTING THE DEBUG OPTION"
exit 1
elif [[  "$IN_ABF" == "1" && -n "$DEBUG" && "$WHO" != "omv" ]]; then
printf "%s\n" "-> Debugging ABF build locally"
#Here we are with ABF=1 and in DEBUG mode,  running on a local system.
# Avoid setting the usual ABF WORKDIR
# if WORKDIR is not defined then set a default'
    if [ -z "$WORKDIR" ]; then
    echo "$SUDOVAR"
    WORKDIR="$UHOME/omdv-build-chroot-$EXTARCH"
    printf "%s\n" "-> The build directory is $WORKDIR"
    fi
fi

if [[ "$IN_ABF" == "1" && -d '/home/omv/docker-iso-worker' ]]; then
    # We really are in ABF
    WORKDIR=$(realpath "$(dirname "$0")")
fi
if [ "$IN_ABF" == "0" ]; then
    if [ -z "$WORKDIR" ]; then
    WORKDIR="$UHOME/omdv-build-chroot-$EXTARCH"
    fi
fi
printf "%s\n" "-> The work directory is $WORKDIR"
# Define these earlier so that files can be moved easily for the various save options
# this is where rpms are installed
CHROOTNAME="$WORKDIR/BASE"
# this is where ISO files are created
ISOROOTNAME="$WORKDIR/ISO"
}

allowedOptions() {
if [ "$ABF" == "1" ]; then
    IN_ABF=1
    printf "%s\n" "-> We are in ABF (https://abf.openmandriva.org) environment"
    if [ -n "$NOCLEAN" ] && [ -n  "$DEBUG" ]; then
    printf "%s\n" "-> using --noclean inside ABF DEBUG instance"
    elif [ -n "$NOCLEAN" ]; then
	printf "%s\n" "-> You cannot use --noclean inside ABF (https://abf.openmandriva.org)"
	exit 1
    fi
# Allow the use of --workdir if in debug mode
    if  [ "$WORKDIR" != "/home/omv/build_iso" ] && [ -n  "$DEBUG" ]; then
    printf "%s\n" "-> using --workdir inside ABF DEBUG instance"
    elif  [ -n  "$WORKDIR" ]; then
	printf "%s\n" "-> You cannot use --workdir inside ABF (https://abf.openmandriva.org)"
	exit 1
    fi
    if [ -n "$KEEP" ]; then
	printf "%s\n" "-> You cannot use --keep inside ABF (https://abf.openmandriva.org)"
	exit 1
    fi
    if	[ -n "$NOCLEAN" ] && [ -n "$REBUILD" ]; then
	printf "%s\n" "-> You cannot use --noclean and --rebuild together"
	exit 1
    fi
    if	[ -n "$REBUILD" ]; then
	printf "%s\n" "-> You cannot use --rebuild inside ABF (https://abf.openmandriva.org)"
	exit 1
    fi
else
    IN_ABF=0
fi
printf  "%s\n" "In abf = $IN_ABF"
}

usage_help() {

    if [[ -z "$EXTARCH" && -z "$TREE" && -z "$VERSION" && -z "$RELEASE_ID" && -z "$TYPE" && -z "$DISPLAYMANAGER" ]]; then
	printf "%s\n" "Please run script with arguments"
	printf "%s\n" "usage $0 [options]"
        printf "%s\n" "general options:"
        printf "%s\n" "--arch= Architecture of packages: i586, x86_64"
        printf "%s\n" "--tree= Branch of software repository: cooker, 3.0, openmandriva2014.0"
        printf "%s\n" "--version= Version for software repository: 2015.0, 2014.1, 2014.0"
        printf "%s\n" "--release_id= Release identifer: alpha, beta, rc, final"
        printf "%s\n" "--type= User environment type on ISO: Plasma, KDE4, MATE, LXQt, IceWM, hawaii, xfce4, weston, minimal"
        printf "%s\n" "--displaymanager= Display Manager used in desktop environemt: KDM, GDM, LightDM, sddm, xdm, none"
        printf "%s\n" "--workdir= Set directory where ISO will be build"
        printf "%s\n" "--outputdir= Set destination directory to where put final ISO file"
        printf "%s\n" "--debug Enable debug output"
        printf "%s\n" "--urpmi-debug Enable urpmi debugging output"
        printf "%s\n" "--noclean Do not clean build chroot and keep cached rpms. Updates chroot with new packages"
        printf "%s\n" "--rebuild Clean build chroot and rebuild from cached rpm's"
        printf "%s\n" "--boot-kernel-type Type of kernel to use for syslinux (eg nrj-desktop), if different from standard kernel"
        printf "%s\n" "--devmode Enables some developer aids see the README"
        printf "%s\n" "--quicken Set up mksqaushfs to use no compression for faster iso builds. Intended mainly for testing"
        printf "%s\n" "--keep Use this if you want to be sure to preserve the diffs of your session when building a new iso session"
        printf "%s\n" "--testrepo Includes the main testing repo in the iso build"
        printf "%s\n" "--auto-update Update the iso filesystem to the latest package versions. Saves rebuilding"
        printf "%s\n" "--enable-skip-list Links a user created skip.list into the /etc/uprmi/ directory. Can be used in conjunction with --auto-update"
        printf "%s\n" " "
        printf "%s\n" "For example:"
        printf "%s\n" "omdv-build-iso.sh --arch=x86_64 --tree=cooker --version=2015.0 --release_id=alpha --type=lxqt --displaymanager=sddm"
        printf "%s\n" "Note that when --type is set to user the user may select their own ISO name during the execution of the script"
        printf "%s\n" "For detailed usage instructions consult the files in /usr/share/omdv-build-iso/docs/"
        printf "%s\n" "Exiting."
	exit 1
    else
	return 0
    fi
}

umountAll() {
    printf "%s\n" "-> Unmounting all."
    unset KERNEL_ISO
    $SUDO umount -l "$1"/proc 2> /dev/null || :
    $SUDO umount -l "$1"/sys 2> /dev/null || :
    $SUDO umount -l "$1"/dev/pts 2> /dev/null || :
    $SUDO umount -l "$1"/dev 2> /dev/null || :
    $SUDO umount -l "$1"/run/os-prober/dev/* 2> /dev/null || :
    $SUDO umount -l "$IMGNME" 2> /dev/null || :
}

errorCatch() {
    printf "%s\n" "-> Something went wrong." "Exiting"
    FilterLogs
    unset KERNEL_ISO
    unset UEFI
    unset MIRRORLIST
    $SUDO umount -l /mnt
    $SUDO losetup -D
if [[ -z "$DEBUG" || -z "$NOCLEAN" || -z "$REBUILD" ]]; then
# for some reason the next line deletes irrespective of flags
#    $SUDO rm -rf $(dirname "$FILELISTS")
    umountAll "$CHROOTNAME"
#    $SUDO rm -rf "$CHROOTNAME"
else
    umountAll "$CHROOTNAME"
fi
#if $1 is set - clean exit
    exit 1
}

# Don't leave potentially dangerous stuff if we had to error out...
trap errorCatch ERR SIGHUP SIGINT SIGTERM

userISONme() {
printf "%s\n" "Please give a name to your iso e.g Enlight"
read -r in1
echo "$in1"
if [ -n "$in1" ]; then
printf "%s\n" "The isoname will be $in1" "Is this correct y or n ?"
cfrmISONme 
fi
printf "%s\n" "Your iso's name will be $UISONAME"
}

cfrmISONme() {    
read -r in2
echo $in2
if [[ $in2 == "yes" || $in2 == "y" ]]; then
UISONAME="$in1"
return 0
fi
if [[ $in2 == "no" || $in2 == "n" ]]; then
userISONme
fi
}

mkISOLabel() {
# Create the ISO directory
$SUDO mkdir -m 0755 -p "$ISOROOTNAME"/EFI/BOOT
# and the grub diectory
$SUDO mkdir -m 0755 -p "$ISOROOTNAME"/boot/grub

# UUID Generation. xorriso needs a string of 16 asci digits.
# grub2 needs dashes to separate the fields..
GRUB_UUID="$(date -u +%Y-%m-%d-%H-%M-%S-00)"
ISO_DATE="$(printf "%s" "$GRUB_UUID" | sed -e s/-//g)"
# in case when i386 is passed, fall back to i586
[ "$EXTARCH" = "i386" ] && EXTARCH=i586

if [ "${RELEASE_ID,,}" == "final" ]; then
    PRODUCT_ID="OpenMandrivaLx.$VERSION"
elif [ "${RELEASE_ID,,}" == "alpha" ]; then
    RELEASE_ID="$RELEASE_ID.$(date +%Y%m%d)"
fi
# Check if user build if true fixup name logic
if [ "$TYPE" = "my.add" ]; then
PRODUCT_ID="OpenMandrivaLx.$VERSION-$RELEASE_ID-$UISONAME"
else
    PRODUCT_ID="OpenMandrivaLx.$VERSION-$RELEASE_ID-$TYPE"
fi
printf "%s" "$PRODUCT_ID"

LABEL="$PRODUCT_ID.$EXTARCH"
[ `echo "$LABEL" | wc -m` -gt 32 ] && LABEL="OpenMandrivaLx_$VERSION"
[ `echo "$LABEL" | wc -m` -gt 32 ] && LABEL="$(echo "$LABEL" |cut -b1-32)"
}

updateSystem() {
printf "%s\n" "$WORKDIR"

	$SUDO urpmq --list-url
	$SUDO urpmi.update -a

	# List of packages that needs to be installed inside lxc-container and local machines
	RPM_LIST="xorriso squashfs-tools syslinux bc imagemagick kpartx gdisk gptfdisk parallel"

	printf "%s\n" "-> Installing rpm files"
    $SUDO urpmi --downloader wget --wget-options --auth-no-challenge --auto --no-suggests --no-verify-rpm --ignorearch ${RPM_LIST} --prefer /distro-theme-OpenMandriva-grub2/ --prefer /distro-release-OpenMandriva/ --auto

    if [ "$IN_ABF" = "0" ]; then
        if [ ! -d "$WORKDIR/dracut" ]; then
            find "$WORKDIR"
            touch "$WORKDIR/.new"
            chown -R "$WHO":"$WHO" "$WORKDIR" #this doesn't do ISO OR BASE
            else
            printf "%s\n" "-> Your build lists have been retained" # Files already copied
        fi
	fi
	# Make our directory writeable by current sudo user
	$SUDO chown -R "$WHO":"$WHO" "$WORKDIR" #this doesn't do ISO OR BASE
}

getPkgList() {
    # update iso-pkg-lists from GitHub if required
    # we need to do this for ABF to ensure any edits have been included
    # Do we need to do this if people are using the tool locally?
    if [[ ( "$IN_ABF" == "1" && -n "$DEBUG" ) || "$IN_ABF" == "0" ]]; then
        if [ ! -d "$WORKDIR/sessrec/base_lists" ]; then
            mkdir -p "$WORKDIR/sessrec/base_lists/"
        fi

        if [ ! -d "$WORKDIR/iso-pkg-lists-${TREE,,}" ]; then
            printf "%s\n" "-> Could not find $WORKDIR/iso-pkg-lists-${TREE,,}. Downloading from GitHub."
            # download iso packages lists from https://github.com
            # GitHub doesn't support git archive so we have to jump through hoops and get more file than we need
            if [ "$TYPE" == "my.add" ]; then
                ISO_VER=cc_user_ver
            elif [ ${TREE,,} == "cooker" ]; then
                ISO_VER=master
            else 
                ISO_VER=${TREE,,}
                # ISO_VER defaults to user entry
            fi
        EXCLUDE_LIST=".abf.yml ChangeLog Developer_Info Makefile README TODO omdv-build-iso.sh omdv-build-iso.spec docs/* tools/*"
        wget -qO- https://github.com/OpenMandrivaAssociation/omdv-build-iso/archive/${ISO_VER}.zip | bsdtar  --cd ${WORKDIR}  --strip-components 1 -xvf -
        cd "$WORKDIR" || exit;
        $SUDO rm -rf ${EXCLUDE_LIST}
        cp -r "$WORKDIR"/iso-pkg-lists* "$WORKDIR/sessrec/base_lists/"	
        fi
        if [ ! -e "$FILELISTS" ]; then
        printf "%s\n" "-> $FILELISTS does not exist. Exiting"
        errorCatch
        fi
    fi
}

showInfo() {

	echo $'###\n'
	printf "%s\n" "Building ISO with arguments:"
	printf "%s\n" "Distribution is $DIST"
	printf "%s\n" "Architecture is $EXTARCH"
	printf "%s\n" "Tree is $TREE"
	printf "%s\n" "Version is $VERSION"
	printf "%s\n" "Release ID is $RELEASE_ID"
	if [ "${TYPE,,}" == "my.add" ]; then
        printf "%s\n" "TYPE is user"
    else    
	printf "%s\n" "Type is $TYPE"
	fi
	if [ "${TYPE,,}" == "minimal" ]; then
	    printf "%s\n" "-> No display manager for minimal ISO."
    elif [ "${TYPE,,}" == "my.add" ] && [ -z "$DISPLAYMANAGER" ]; then
        printf "%s\n" "-> No display manager for user ISO."
	else
	    printf "%s\n" "Display Manager is $DISPLAYMANAGER"
	fi
	printf "%s\n" "ISO label is $LABEL"
	printf "%s\n" "Build ID is $BUILD_ID"
	printf "%s\n" "Working directory is $WORKDIR"
	if  [ -n "$REBUILD" ]; then
	    printf "%s\n" "-> All rpms will be re-installed"
	elif [ -n "$NOCLEAN" ]; then
	    printf "%s\n" "-> Installed rpms will be updated"
	fi
	if [ -n "$DEBUG" ]; then
	    printf "%s\n" "-> Debugging enabled"
	fi
	if [ -n "$QUICKEN" ]; then
	    printf "%s\n" "-> Squashfs compression disabled"
	fi
	if [ -n "$COMPTYPE" ]; then
	    printf "%s\n" "-> Using ${COMPTYPE} for Squashfs compression"
	fi
	if [ -n "$KEEP" ]; then
	    printf "%s\n" "-> The session diffs will be retained"
	fi
	if [ -n "$ENSKPLST" ]; then
        printf "%\n" "-> urpmi skip list enabled"
    fi
	printf "%s\n" "###" " "
}

localMd5Change() {
# Usage: userMd5Change [VARNAME] {Name of variable to contain diff list}
# Function:
# Creates md5sums current iso package list directory and store to file if file does not already exist.
# Three files are created "$WORKDIR/filesums", "/tmp/filesums" and $WORKDIR/chngsense
# The first two contain file md5's for the original set and the current set, the last contains the checksum for the entire directory.
# On each run the directory md5sums are compared if there has been a change a flag is set triggering modification of the chroot.
# If the flag is set the md5s for the files are compared and a named variable containing the changed files is emmitted.
# This variable is used as input for diffPkgLists() to generate diffs for the information of the developer/user
# This function is not used when the script is run on ABF.

	if [[ "$IN_ABF" == "1" && -z "$DEBUG" ]]; then
        return 0
    fi
   	local __difflist
    BASE_LIST=$WORKDIR/sessrec/base_lists/iso-pkg-lists-${TREE}
    WORKING_LIST=$WORKDIR/iso-pkg-lists-${TREE}
       	
    if [ -f "$WORKDIR/.new" ]; then
        printf "%s\n" "-> Making reference file sums"
        REF_FILESUMS=$($SUDO find ${BASE_LIST}/my.add ${BASE_LIST}/my.rmv ${BASE_LIST}/*.lst -type f -exec md5sum {} \; | tee "$WORKDIR/sessrec/ref_filesums")
        printf "%s\n" "-> Making directory reference sum"
        REF_CHGSENSE=$(printf "%s" "$REF_FILESUMS" | colrm 33 | md5sum | tee "$WORKDIR/sessrec/ref_chgsense")
        printf "%s\n" "$BUILD_ID" > "$WORKDIR/sessrec/.build_id"
        printf "%s\n" "-> Recording build identifier"
        $SUDO rm -rf "$WORKDIR/.new"
    elif [ -n "$NOCLEAN" ]; then
        # Regenerate the references for the next run
        REF_FILESUMS=$($SUDO find ${BASE_LIST}/my.add ${BASE_LIST}/my.rmv ${BASE_LIST}/*.lst -type f -exec md5sum {} \; | tee "$WORKDIR/sessrec/ref_filesums")
        printf "%s\n" "-> Making reference file sums"
        REF_CHGSENSE=$(printf "%s" "$REF_FILESUMS" | colrm 33 | md5sum | tee "$WORKDIR/sessrec/ref_chgsense")
        printf "%s\n" "-> Making directory reference sum"
    fi
        if [ -n "$DEBUG" ]; then
            printf "%s\n" "$REF_CHGSENSE"
            printf "%s\n" "$REF_FILESUMS"
        fi
    
    REF_CHGSENSE=$(cat "$WORKDIR/sessrec/ref_chgsense")
    REF_FILESUMS=$(cat "$WORKDIR/sessrec/ref_filesums")
    printf "%s\n" "-> References loaded"
    
	# Generate the references for this run
	# Need to be careful here; there may be backup files so get the exact files
    # Order is important (sort?)
        NEW_FILESUMS=$($SUDO find ${WORKING_LIST}/my.add ${WORKING_LIST}/my.rmv ${WORKING_LIST}/*.lst -type f -exec md5sum {} \; | tee $WORKDIR/sessrec/new_filesums)
    NEW_CHGSENSE=$(printf "%s" "$NEW_FILESUMS" | colrm 33 | md5sum | tee "$WORKDIR/sessrec/new_chgsense")
    printf "%s\n" "-> New references created" 
    if [ -n "$DEBUG" ]; then
        printf "%s\n" "Directory Reference checksum" "$REF_CHGSENSE"
        printf "%s\n" "Reference Filesums" "$REF_FILESUMS" 
        printf "%s\n" "New Directory Reference checksum" "$NEW_CHGSENSE" 
        printf "%s\n" "New Filesums"  "$NEW_FILESUMS" 
    fi
        if [ "$NEW_CHGSENSE" == "$REF_CHGSENSE" ]; then
        CHGFLAG=0
        else
        $SUDO printf "%s\n" "$NEW_CHGSENSE" >"$WORKDIR/sessrec/ref_chgsense"
        CHGFLAG=1
        fi
	if [ "$CHGFLAG" == "1" ]; then
	    printf "%s\n" "-> Your build files have changed"
	# Create a list of changed files by diffing checksums
    # In these circumstances awk does a better job than diff
    # This looks complicated but all it does is to put the two fields in each file into independent arrays,
    # compares the first field from each file and if they are not equal then print the second field (filename) from each file.
        DIFFILES=$(awk 'NR==FNR{c[NR]=$2; d[NR]=$1;next}; {e[FNR]=$1; f[FNR]=$2}; {if(e[FNR] == d[FNR]){} else{print c[FNR],"   "f[FNR]}}' "$WORKDIR/sessrec/ref_filesums" "$WORKDIR/sessrec/new_filesums") 
        MODFILES="${DIFFILES}"
        if [ -n "$DEBUG" ]; then 
            printf "%s\n" "$MODFILES"
        fi
        #$SUDO mv "$WORKDIR/sessrec/tmp_new_filesums" "$WORKDIR/sessrec/new_filesums"
        USERMOD=$(printf '%s' "$DIFFILES" | grep 'my.add\|my.rmv')
        if [ -z "$USERMOD" ]; then
            printf "%s\n" "-> No Changes"
            return 0
        fi
    # Here just the standard files are diffed ommitting my.add and my.remove
    # Intended for developers creating new compilations. Only active if DEVMODE is set in the env.
    # This list is intended for Developers
    DEVMOD=$(printf '%s' "$DIFFILES" | grep -v 'my.add\|my.rmv')
    # Create a diff for the users reference
        diffPkgLists "$USERMOD"
    elif [[ -n "$DEBUG"  && ( -n "$DEVMOD" || -n "$DEVMODE" ) ]]; then #DEVMOD not empty so run a full update.
    # Create a developer diff ommitting my.add and my.rmv
    diffPkgLists "$DEVMOD"
    fi
}

getIncFiles() {
# Usage: getIncFiles [filename] xyz.* $"[name of variable to return] 
# Returns a sorted list of include files
# Function: Gets all the include lines for the specified package file
# The full path to the package list must be supplied

# Define a some local variables
    local __infile=$1   # The main build file
    local __incflist=$2 # Carries returned variable
getEntrys() {
    # Recursively fetch included files
    while read -r r; do 
     echo "$r"
	[ -z "$r" ] && continue 
	# $'\n' nothing else works just don't go there.
	__addrpminc+=$'\n'"$WORKDIR/iso-pkg-lists-$TREE/$r" 
	getEntrys "$WORKDIR/iso-pkg-lists-$TREE/$r" 
# Avoid sub-shells make sure commented out includes are removed.
    done < <(cat "$1" | grep  '^[A-Za-z0-9 \t]*%include' | sed '/ #/d' | awk -F\./// '{print $2}' | sed '/^\s$/d' | sed '/^$/d') > /dev/null 2>&1
}
     getEntrys "$1"
   # Add the primary file to the list
   	__addrpminc+=$'\n'"$__infile"
    # Sort and remove dupes.
   	__addrpminc=$(printf "%s" "$__addrpminc" | sort -u | uniq -u) 
   	# Export
    eval $__incflist="'$__addrpminc'"
} 

createPkgList() {
# Usage: createPkgList  "$VAR" VARNAME
# Function: Creates lists of packages from package lists
# VAR: A variable containing a list of package lists
# VARNAME: A variable name to identify the returned list of packages.
# Intent: Can be used to generate named variables
# containing packages to install or remove.

# NOTE: This routine requires 'lastpipe' so that
# subshells do not dump their data.
# This requires that job control be disabled.
    set +m
    shopt -s lastpipe
# Define a local variable to hold user VAR
    local __pkglist=$2 # Carries returned variable name
# other locals not needed outside routine
    local __pkgs # The list of packages
    local __pkglst # The current package list
    while read -r __pkglst; do
	__pkgs+=$'\n'$(cat "$__pkglst" 2> /dev/null)
    done < <(printf '%s\n' "$1") 
# sanitise regex compliments of TPG
    __pkgs=$(printf '%s\n' "$__pkgs" | grep -v '%include' | sed -e 's,        , ,g;s,  *, ,g;s,^ ,,;s, $,,;s,#.*,,' | sed -n '/^$/!p' | sed 's/ $//')
    #The above was getting comments that occured after the package name i.e. vim-minimal #mini-iso9660. but was leaving a trailing space which confused parallels and it failed the install

    eval $__pkglist="'$__pkgs'"
    if [ -n "$DEBUG" ]; then
	printf  "%s\n" "-> This is the $2 package list"
	printf "%s\n" "$__pkgs"
	$SUDO printf "%s" "$__pkgs" >"$WORKDIR/$2.list"
    fi

    shopt -u lastpipe
    set -m
}


diffPkgLists() {
# Usage verifyPkgLists $(LIST_VARIABLE)
# The "LIST VARIABLE" contains a 'side by side' list of filenames to be diffed.
# Compares the users set of rpm lists with the shipped set
# Intent. Used to determine whether changes have occurred in the users set of rpm lists.
# Diffs are numbered sequentially each time the script is run with --noclean or --rebuild set
# The primary name of the diff is derived from the $WORKDIR thus the diffs remain in context with the session.
# The diffs generated are culmulative which means that each diff is the sum of all the previous diffs
# thus each diff created contains the entire record of the session.
# Running without --noclean set destroys the $WORKDIR and thus the diffs.
# Adding the --keep flag will move the diffs to the users home directory. They will be moved back at
# the start of each new session if the --keep flag is set and --noclean or --rebuild are selected.

    local __difflist="$1"
	local __newdiffname
	local dodiff="/usr/bin/diff -Naur"
	
	# Here a combined diff is created
	while read -r DIFF ; do
	ALL+=$(eval  "$dodiff" "$DIFF")$'\n'
	done < <(printf '%s\n' "$__difflist")
	
	if [ -n "$__difflist" ]; then
	# BUILD_ID and SEQNUM are used to label diffs
        if [ -f "$WORKDIR/sessrec/.build_id" ]; then
                SESSNO=$(cat "$WORKDIR"/sessrec/.build_id)
        else
            SESSNO=${BUILD_ID}
        fi
        if [ -f "$WORKDIR/sessrec/.seqnum" ]; then
            SEQNUM=$(cat "$WORKDIR"/sessrec/.seqnum)
        else
            SEQNUM=1
            $SUDO echo "$SEQNUM" >"$WORKDIR/sessrec/.seqnum"
        fi
        __newdiffname="${SESSNO}_${SEQNUM}.diff"
        $SUDO printf "%s" "$ALL" >"$WORKDIR"/sessrec/"$__newdiffname"
        SEQNUM=$((SEQNUM+1))
        $SUDO printf "$SEQNUM" >"$WORKDIR/sessrec/.seqnum"
    fi
}

mkOmSpin() {
# Usage: mkOmSpin [main install file path} i.e. [path]/omdv-kde4.lst.
# Returns a variable "$INSTALL_LIST" containing all rpms
# to be installed
    getIncFiles "$FILELISTS" ADDRPMINC
    printf "%s" "$ADDRPMINC" > "$WORKDIR/inclist"
    printf "%s\n" "-> Creating OpenMandriva spin from" "$FILELISTS" " " "   Which includes"
    printf "%s" "$ADDRPMINC" | grep -v "$FILELISTS"  
    createPkgList "$ADDRPMINC" INSTALL_LIST
    if [ -n "$DEVMODE" ]; then
    printf '%s' "$INSTALL_LIST" >"$WORKDIR/rpmlist"
    fi
    mkUpdateChroot "$INSTALL_LIST"
}

#mkRpmDb() {
#Use $INSTALL_LIST to create db from synthesis hdlist.




updateUserSpin() {
# updateUserSpin [main install file path] i.e. path/omdv-kde4.lst
# Sets two variables
# INSTALL_LIST = All list files to be installed
# REMOVE_LIST = All list files to be removed
# This function only updates using the user my.add and my.rmv files.
# It is used to add user updates after the main chroot
# has been created with mkUserSpin.
    printf "%s\n" "-> Updating user spin"
    getIncFiles "$WORKDIR/iso-pkg-lists-$TREE/my.add" UADDRPMINC
# re-assign just for consistancy
    ALLRPMINC="$UADDRPMINC"
    getIncFiles "$WORKDIR/iso-pkg-lists-$TREE/my.rmv" RMRPMINC
# "Remove any duplicate includes"
RMRPMINC=$(comm -1 -3 <(printf '%s\n' "$ALLRPMINC" | sort ) <(printf '%s\n' "$RMRPMINC" | sort))
    createPkgList "$ALLRPMINC" INSTALL_LIST
    createPkgList "$RMRPMINC" REMOVE_LIST
	printf "%s\n" " " "-> This is the user list"
	printf "%s\n" "$ALLRPMINC"
	printf "%s\n" " " "-> This is the remove list"
	printf "%s\n" "$RMRPMINC" " "
	if [ -n "$DEVMODE" ]; then
	$SUDO printf '%s\n' "$ALLRPMINC" >"$WORKDIR/add_incfile.list" " "
	$SUDO printf '%s\n' "$RMRPMINC" >"$WORKDIR/remove_incfile.list" " "
    fi
#    Remove any packages that occur in both lists
#    REMOVE_LIST=`comm -1 -3 --nocheck-order <(printf '%s\n' "$INSTALL_LIST" | sort) <(printf '%s\n' "$PRE_REMOVE_LIST" | sort)`
printf "%s\n" "$REMOVE_LIST"
    if [ -n "$DEVMODE" ]; then
	$SUDO printf '%s\n' "$INSTALL_LIST" >"$WORKDIR/user_update_add_rpmlist" " "
	$SUDO printf '%s\n' "$REMOVE_LIST" >"$WORKDIR/user_update_rm_rpmlist" " "
    fi
    mkUpdateChroot  "$INSTALL_LIST" "$REMOVE_LIST"
        printf "%s\n" "$INSTALL_LIST" "$REMOVE_LIST"
}

mkUserSpin() {
# mkUserSpin [main install file path} i.e. [path]/omdv-kde4.lst
# Sets two variables
# $INSTALL_LIST = All list files to be installed
# $REMOVE_LIST = All list files to be removed
# This function includes all the user adds and removes.
    printf "%s\n" "-> Making a user spin"
    printf "%s\n" "Change Flag = $CHGFLAG"

    getIncFiles "$FILELISTS" ADDRPMINC 
    #"$TYPE"
    printf "%s\n" "$ADDRPMINC" > "$WORKDIR/prime.list"
    getIncFiles "$WORKDIR/iso-pkg-lists-$TREE/my.add" UADDRPMINC
    ALLRPMINC=$(echo "$ADDRPMINC"$'\n'"$UADDRPMINC" | sort -u)
    printf "%s\n" "$ALLRPMINC" > "$WORKDIR/primary.list"
    getIncFiles "$WORKDIR/iso-pkg-lists-$TREE/my.rmv" RMRPMINC
    printf "%s\n" "-> Remove the common include lines for the remove package includes" 
    RMRPMINC=$(comm -1 -3 <(printf '%s\n' "$ALLRPMINC" | sort ) <(printf '%s\n' "$RMRPMINC" | sort))
    printf "%s" "-> Creating $WHO's OpenMandriva spin from $FILELISTS" "  Which includes "
    printf "%s\n" "$ALLRPMINC" | grep -v "$FILELISTS"
    # Create the package lists
    createPkgList "$ALLRPMINC" INSTALL_LIST
    createPkgList "$RMRPMINC" REMOVE_LIST

    if [ -n "$DEVMODE" ]; then
	$SUDO printf '%s\n' "$INSTALL_LIST" >"$WORKDIR/user_add_rpmlist"
	$SUDO printf '%s\n' "$REMOVE_LIST" >"$WORKDIR/user_rm_rpmlist"
    fi
    mkUpdateChroot "$INSTALL_LIST" "$REMOVE_LIST"
}

# The MyAdd and MyRmv finctionsCan't take full advantage of parallel until a full rpm dep list is produced which means using a solvedb setup. We can however make use of it's fail utility.. Add some logging too.

MyAdd() {
# Usage: MyAdd
        if [ -n "$__install_list" ]; then 
            printf "%s\n" "-> Installing user package selection" " "
            printf "%s\n" "$__install_list" | parallel -q --keep-order --joblog "$WORKDIR/install.log" --tty --halt now,fail=$MAXERRORS -P 1 /usr/sbin/urpmi --noclean --urpmi-root "$CHROOTNAME" --download-all --no-suggests --fastunsafe --ignoresize --nolock --auto  | tee "$WORKDIR/urpmopt.log"
            $SUDO printf "%s\n" "$__install_list" >"$WORKDIR/RPMLIST.txt"
        fi
}

MyRmv() {
# Usage: MyRmv 
        if [ -n "$__remove_list" ]; then
            printf "%s" "-> Removing user specified rpms and orphans"
            # rpm is used here to get unconditional removal. urpme's idea of a broken system does not comply with our minimal install.
            printf '%s\n' "$__remove_list" | parallel --tty --halt now,fail=10 -P 1 $SUDO rpm -e -v --nodeps --noscripts --root "$CHROOTNAME"
            #--dbpath "$CHROOTNAME/var/lib/rpm"       
            # This exposed a bug in urpme
            $SUDO urpme --urpmi-root "$CHROOTNAME"  --auto --auto-orphans --force
            #printf '%s\n' "$__removelist" | parallel --dryrun --halt now,fail=10 -P 6  "$SUDO" urpme --auto --auto-orphans --urpmi-root "$CHROOTNAME"
        else
            printf "%s\n" " " "-> No rpms need to be removed"
        fi
}
 
mkUpdateChroot() {
# Usage: mkUpdateChroot [Install variable] [remove variable]
# Function:      If the --noclean option is set and a full chroot has been built
#               (presence of .noclean in the chroot directory) then this function will be
#               called when a change is detected in the users iso-build-lists.
#               If the rebuild flag is set the entire chroot will be rebuilt using
#               the main and user created configurations lists.
#               It will first add any specified packages to the current chroot
#               and then remove the specified packages using the auto-orphan option
#               if the variable is not empty.
#               As a minimum the INSTALL_LIST must exist in the environment.
#               The optional REMOVE_LIST  can also be supplied.
#               These variables must contain lists of newline
#               separated package names for installation or removal.
#               The variable names are flexible but their content and order on the commandline
#               are mandatory.
	printf "%s\n\n" "-> Updating chroot"
	local __install_list="$1"
	local __remove_list="$2"

    if [ "$IN_ABF" == "0" ]; then
        
        # Sometimes the order of add and remove are critical for example if a package needs to be replaced with the same package the package needs to be removed first thus the remove list needs to be run first
        # If the same package exists in both add and remove lists then remove list needs to be run first but there no point in running a remove list first if there's no rpms to remove because 
        # they haven't been installed yet. So removing rpms only needs to be invoked first if the NOCLEAN flag is set indicating a built chroot. The problem is that the replacepkgs flag does not install if the package has not been installed
        # that are already there so the package has to be removed first otherwise parts of the install list will fail. A replace list could be provided
        # A simple fix for the moment turn both operations into functions and call then through logic which determines whether --noclean has been invoked.
        # Needs more work though as --noclean can be invoked without an existing chroot so need to check for this exception
        if [ -n "$NOCLEAN" ]; then
            MyRmv
            MyAdd
        else
            MyAdd
            MyRmv
        fi
    elif [ "$IN_ABF" == "1" ]; then
    #printf "%s\n" "-> Installing packages at ABF"
        if [ -n "$PLLL" ]; then
        printf "%s\n" "$__install_list" | parallel -q --keep-order --joblog "$WORKDIR/install.log" --tty --halt now,fail="$MAXERRORS" -P 1 /usr/sbin/urpmi --noclean --urpmi-root "$CHROOTNAME" --download-all --no-suggests --fastunsafe --ignoresize --auto | tee "$WORKDIR/urpmopt.log"
        else
        printf '%s\n' "$__install_list" | xargs $SUDO /usr/sbin/urpmi --noclean --urpmi-root "$CHROOTNAME" --download-all --no-suggests --fastunsafe --ignoresize --nolock --auto ${URPMI_DEBUG}
        fi
   fi
}

    FilterLogs() {
        printf "%s\n" "-> Make some helpful logs"
        #Create the header
        printf "%s\n" "" "" "RPM Install Success" " " >"$WORKDIR/rpm-install.log" 
        head -1 "$WORKDIR/install.log" | awk '{print$1"\t"$3"\t"$4"\t"$7"  "$8"  "$9"\t"$19}' >>"$WORKDIR/rpm-install.log" #1>&2 >/dev/null
        printf "%s\n" "" "" "RPM Install Failures" " " >"$WORKDIR/rpm-fail.log" 
        head -1 "$WORKDIR/install.log"  | awk '{print$1"\t"$3"\t"$4"\t"$7"  "$8"  "$9"\t"$19}' >>"$WORKDIR/rpm-fail.log" 
        cat rpm-install.log | awk '$7  ~ /0/ {print$1"\t"$3"\t"$4"\t"$7"  "$8"  "$9"\t"$19}'
        #Append the data
        cat "$WORKDIR/install.log" | awk '$7  ~ /1/  {print$1"\t"$3"\t"$4"\t\t"$7"\t "$8"\t "$9" "$19}'>> "$WORKDIR/rpm-fail.log"
        cat "$WORKDIR/install.log" | awk '$7  ~ /0/  {print$1"\t"$3"\t"$4"\t\t"$7"\t "$8"\t "$9" "$19}' >> "$WORKDIR/rpm-install.log"
        # Make a dependency failure log
        if [ -f "$WORKDIR/urpmopt.log" ]; then
         grep -hr -A1 'A requested package cannot be installed:' "$WORKDIR/urpmopt.log" | sort -u >depfail.log
        fi
        if [[ "$IN_ABF" == "1" && -f "$WORKDIR/install.log" ]]; then
         cat "$WORKDIR/rpm-fail.log"
         printf "%s\n" " " "-> DEPENDENCY FAILURES"
         cat "$WORKDIR/depfail.log"
         cat "$WORKDIR/rpm-install.log" 
        fi
        #Clean-up
        rm -f "$WORKDIR/install.log"
}

createChroot() {
# Usage: createChroot packages.lst /target/dir
# Creates a chroot environment with all packages in the packages.lst
# file and their dependencies in /target/dir

if [ "$CHGFLAG" != "1" ]; then
    if [[ ( -f "$CHROOTNAME"/.noclean && ! -d "$CHROOTNAME/lib/modules") || -n "$REBUILD" ]]; then 
        printf "%s\n" "-> Creating chroot $CHROOTNAME" 
    else 
        printf "%s\n" "-> Updating existing chroot $CHROOTNAME"
    fi
# Make sure /proc, /sys and friends are mounted so %post scripts can use them
# Note that below mkdir -p creates $WORKDIR/BASE 
    $SUDO mkdir -p "$CHROOTNAME/proc" "$CHROOTNAME/sys" "$CHROOTNAME/dev" "$CHROOTNAME/dev/pts"

    if [[ -n "$REBUILD" && -z "$NOCLEAN" ]]; then
	    ANYRPMS=$(find "$CHROOTNAME/var/cache/urpmi/rpms/" -name "basesystem-minimal*.rpm"  -type f  -printf %f)
        if [ -z "$ANYRPMS" ]; then
            printf "%s\n" "-> You must run with --noclean before you use --rebuild"
            errorCatch
        fi
	else
    printf "%s\n" "-> Rebuilding." 
	fi
fi

# If chroot exists and if we have --noclean then the repo files are not needed with exception of the
# first time run with --noclean when they must be installed. If --rebuild is called they will have been
# deleted so reinstall them. 
    REPOPATH="http://abf-downloads.openmandriva.org/${TREE,,}/repository/$EXTARCH/"
    printf "%s" "$REPOPATH"
# If the kernel hasn't been installed then it's a new chroot or a rebuild
    if [[ ! -d "$CHROOTNAME"/lib/modules || -n "$REBUILD" ]]; then
#    if [[ -n "$NOCLEAN" || -n "$REBUILD" ]]; then
	printf "%s\n" "-> Adding urpmi repository $REPOPATH into $CHROOTNAME" " "
        if [ "$FREE" = "0" ]; then
        $SUDO urpmi.addmedia --wget --urpmi-root "$CHROOTNAME" --distrib $REPOPATH
        else
        $SUDO urpmi.addmedia --wget --urpmi-root "$CHROOTNAME" "Main" $REPOPATH/main/release
        $SUDO urpmi.addmedia --wget --urpmi-root "$CHROOTNAME" "Contrib" $REPOPATH/contrib/release
        # This one is needed to grab firmwares
        $SUDO urpmi.addmedia --wget --urpmi-root "$CHROOTNAME" "Non-free" $REPOPATH/non-free/release
            # and this one for the users local stuff 
#        $SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" "local" file://home/colin/Development/fixuprepo
        fi
        if [ "${TREE,,}" != "cooker" ]; then
        $SUDO urpmi.addmedia --wget --urpmi-root "$CHROOTNAME" "MainUpdates" $REPOPATH/main/updates
        $SUDO urpmi.addmedia --wget --urpmi-root "$CHROOTNAME" "ContribUpdates" $REPOPATH/contrib/updates
    # This one is needed to grab firmwares
        $SUDO urpmi.addmedia --wget --urpmi-root "$CHROOTNAME" "Non-freeUpdates" $REPOPATH/non-free/updates
    # and this one for the users local stuff 
#        $SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" "local" file://home/colin/Development/fixuprepo

        fi
	fi

# Update media
     if [ -n "$TESTREPO" ]; then
        $SUDO urpmi.addmedia --wget --urpmi-root "$CHROOTNAME" "MainTesting" $REPOPATH/main/testing
     fi
    $SUDO urpmi.update -a -c -ff --wget --urpmi-root "$CHROOTNAME" main
    if [ "${TREE,,}" != "cooker" ]; then
        printf "%s -> Updating urpmi repositories in $CHROOTNAME"
        $SUDO urpmi.update -a -c -ff --wget --urpmi-root "$CHROOTNAME" updates
    fi

    $SUDO mount --bind /proc "$CHROOTNAME"/proc
    $SUDO mount --bind /sys "$CHROOTNAME"/sys
    $SUDO mount --bind /dev "$CHROOTNAME"/dev
    $SUDO mount --bind /dev/pts "$CHROOTNAME"/dev/pts

# Start rpm packages installation 
# CHGFLAG=1 Indicates a global change in the iso lists

# If we are IN_ABF=1 then build a standard iso
# If we are IN_ABF=1 and DEBUG is set then we are running the ABF mode locally. 
# In this mode the NOCLEAN flag is allowed. 
# If set this will build a standard iso initially once built subsequent runs 
# with NOCLEAN set will update the chroot with any changed file entries.

# If the NOCLEAN flag is set this will build an iso using the standard files 
# plus the contents of the two user files my.add and my.rmv. 
# Once built subsequent runs with NOCLEAN set will update the chroot with 
# any changed entries in the user files only. 
# if --rebuild is set then rebuild the chroot using the standard and user file lists. 
# This uses the preserved rpm cache to speed up the rebuild. 
# Files that were added to the user files will be downloaded.

    # Build from scratch
    if [[ -z "$NOCLEAN" && -z "$REBUILD" ]]; then
        printf "%s\n" "Creating chroot" 
        mkOmSpin
     # Build the initial noclean chroot this is user mode only and will include the two user files my.add and my.rmv
    elif [[ -n "$NOCLEAN" && ! -e "$CHROOTNAME"/.noclean && "$IN_ABF" == "0" ]]; then 
        printf "%s\n" "Creating an user chroot"
        mkUserSpin
     # Build the initial noclean chroot in ABF test mode and will use just the base lists   
    elif [[ -n "$NOCLEAN" && ! -e "$CHROOTNAME"/.noclean && "$IN_ABF" == "1" && -n "$DEBUG" ]]; then
#    elif [[ -n "$NOCLEAN" && ! -e "$CHROOTNAME"/.noclean && "$IN_ABF" == "1" ]]; then    
        printf "%s\n" "Creating chroot in ABF developer mode"
        mkOmSpin
    # Update a noclean chroot with the contents of the user files my.add and my.rmv 
    elif [[ -n "$AUTO_UPDATE" && -n "$NOCLEAN" && -e "$CHROOTNAME"/.noclean && "$IN_ABF" == "0" ]]; then
        #$SUDO chroot "$CHROOTNAME"
       $SUDO /usr/sbin/urpmi --auto-update --force --urpmi-root "$CHROOTNAME"
    elif 
    [[ -n "$NOCLEAN" && -e "$CHROOTNAME"/.noclean && "$IN_ABF" == "0" ]]; then
        updateUserSpin
        printf "%s\n" "-> Updating user spin"
    # Rebuild the users chroot from cached rpms
    elif [ -n "$REBUILD" ]; then
        printf  "%s\n" "-> Rebuilding." 
        mkUserSpin "$FILELISTS"
    fi
 
	$SUDO touch "$CHROOTNAME/.noclean"
 

    if [[ $? != 0 ]] && [ ${TREE,,} != "cooker" ]; then
	printf "%s\n" "-> Can not install packages from $FILELISTS"
	errorCatch
    fi

# Check CHROOT
    if [ ! -d  "$CHROOTNAME"/lib/modules ]; then
	printf "%s\n" "-> Broken chroot installation." "Exiting" 
	errorCatch
    fi
# Export installed and boot kernel
    pushd "$CHROOTNAME"/lib/modules > /dev/null 2>&1
    BOOT_KERNEL_ISO="$(ls -d --sort=time [0-9]*-${BOOT_KERNEL_TYPE}* | head -n1 | sed -e 's,/$,,')"
    export BOOT_KERNEL_ISO
    if [ -n "$BOOT_KERNEL_TYPE" ]; then
	$SUDO echo "$BOOT_KERNEL_TYPE" > "$CHROOTNAME/boot_kernel"
	KERNEL_ISO=$(ls -d --sort=time [0-9]* | grep -v "$BOOT_KERNEL_TYPE" | head -n1 | sed -e 's,/$,,')
    else
	KERNEL_ISO=$(ls -d --sort=time [0-9]* |head -n1 | sed -e 's,/$,,')
    fi
    export KERNEL_ISO
    popd > /dev/null 2>&1
# remove rpm db files which may not match the target chroot environment
    $SUDO chroot "$CHROOTNAME" rm -f /var/lib/rpm/__db.*
}

createInitrd() {
# Check if dracut is installed
    if [ ! -f "$CHROOTNAME/usr/sbin/dracut" ]; then
	printf "%s\n" "-> dracut is not installed inside chroot." "Exiting."
	errorCatch
    fi

# Build initrd for syslinux
    printf "%s\n" "-> Building liveinitrd-$BOOT_KERNEL_ISO for ISO boot"
    if [ ! -f "$WORKDIR/dracut/dracut.conf.d/60-dracut-isobuild.conf" ]; then
	printf "%s\n" "-> Missing $WORKDIR/dracut/dracut.conf.d/60-dracut-isobuild.conf." "Exiting."
	errorCatch
    fi

    $SUDO cp -f "$WORKDIR"/dracut/dracut.conf.d/60-dracut-isobuild.conf "$CHROOTNAME"/etc/dracut.conf.d/60-dracut-isobuild.conf

    if [ ! -d "$CHROOTNAME"/usr/lib/dracut/modules.d/90liveiso ]; then
	printf "%s\n" "-> Dracut is missing 90liveiso module. Installing it." 

	if [ ! -d "$WORKDIR"/dracut/90liveiso ]; then
	    printf "%s\n" "-> Cant find 90liveiso dracut module in $WORKDIR/dracut. Exiting." " "
	    errorCatch
	fi

	$SUDO cp -a -f "$WORKDIR"/dracut/90liveiso "$CHROOTNAME"/usr/lib/dracut/modules.d/
	$SUDO chmod 0755 "$CHROOTNAME"/usr/lib/dracut/modules.d/90liveiso
	$SUDO chmod 0755 "$CHROOTNAME"/usr/lib/dracut/modules.d/90liveiso/*.sh
    fi

# Fugly hack to get /dev/disk/by-label
    $SUDO sed -i -e '/KERNEL!="sr\*\", IMPORT{builtin}="blkid"/s/sr/none/g' -e '/TEST=="whole_disk", GOTO="persistent_storage_end"/s/TEST/# TEST/g' "$CHROOTNAME"/lib/udev/rules.d/60-persistent-storage.rules
    if [[ $? != 0 ]]; then
	printf "%s\n" "-> Failed with editing /lib/udev/rules.d/60-persistent-storage.rules file. Exiting."
	errorCatch
    fi

    if [ -f "$CHROOTNAME"/boot/liveinitrd.img ]; then
	$SUDO rm -rf "$CHROOTNAME"/boot/liveinitrd.img
    fi

# Set default plymouth theme
    if [ -x "$CHROOTNAME"/usr/sbin/plymouth-set-default-theme ]; then
	chroot "$CHROOTNAME" /usr/sbin/plymouth-set-default-theme OpenMandriva
    fi

# Building liveinitrd
    $SUDO chroot "$CHROOTNAME" /usr/sbin/dracut -N -f --no-early-microcode --nofscks --noprelink  /boot/liveinitrd.img --conf /etc/dracut.conf.d/60-dracut-isobuild.conf "$KERNEL_ISO"

    if [ ! -f "$CHROOTNAME"/boot/liveinitrd.img ]; then
	printf "%s\n" "-> File $CHROOTNAME/boot/liveinitrd.img does not exist. Exiting."
	errorCatch
    fi

    printf "%s\n" "-> Building initrd-$KERNEL_ISO inside chroot"
# Remove old initrd
    $SUDO rm -rf "$CHROOTNAME/boot/initrd-$KERNEL_ISO.img"
    $SUDO rm -rf "$CHROOTNAME"/boot/initrd0.img

# Remove config before building initrd
    $SUDO rm -rf "$CHROOTNAME"/etc/dracut.conf.d/60-dracut-isobuild.conf
    $SUDO rm -rf "$CHROOTNAME"/usr/lib/dracut/modules.d/90liveiso

# Building initrd
    $SUDO chroot "$CHROOTNAME" /usr/sbin/dracut -N -f "/boot/initrd-$KERNEL_ISO.img" "$KERNEL_ISO"
    if [[ $? != 0 ]]; then
	printf "%s\n" "-> Failed creating initrd. Exiting."
	errorCatch
    fi

# Build the boot kernel initrd in case the user wants it kept
    if [ -n "$BOOT_KERNEL_TYPE" ]; then
# Building boot kernel initrd
        printf "%s\n" "-> Building initrd-$BOOT_KERNEL_ISO inside chroot"
        $SUDO chroot "$CHROOTNAME" /usr/sbin/dracut -N -f "/boot/initrd-$BOOT_KERNEL_ISO.img" "$BOOT_KERNEL_ISO"
	if [[ $? != 0 ]]; then
	    printf "%s\n" "-> Failed creating boot kernel initrd. Exiting."
	    errorCatch
	fi
    fi

    $SUDO ln -sf "/boot/initrd-$KERNEL_ISO.img" "$CHROOTNAME/boot/initrd0.img"

}

createMemDisk () {
# Usage: createMemDIsk <target_directory/image_name>.img <grub_support_files_directory> <grub2 efi executable>
# Creates a fat formatted file ifilesystem image which will boot an UEFI system.

    if [ $EXTARCH = "x86_64" ]; then
	ARCHFMT=x86_64-efi
	ARCHPFX=X64
    else
	ARCHFMT=i386-efi
	ARCHPFX=IA32
    fi

    ARCHLIB="/usr/lib/grub/$ARCHFMT"
    EFINAME=BOOT"$ARCHPFX.efi"
    printf "%s\n" "-> Setting up UEFI memdisk image."
    GRB2FLS="$ISOROOTNAME/EFI/BOOT"
# Create memdisk directory
    if [ -e "$WORKDIR/boot/grub" ]; then
	$SUDO /bin/rm -R "$WORKDIR/boot/grub"
	$SUDO mkdir -p "$WORKDIR/boot/grub"
    else
	$SUDO mkdir -p "$WORKDIR/boot/grub"
    fi
    MEMDISKDIR="$WORKDIR/boot/grub"

# Copy the grub config file to the chroot dir for UEFI support
# Also set the uuid
    $SUDO cp -f "$WORKDIR/grub2/start_cfg" "$MEMDISKDIR/grub.cfg"
    $SUDO sed -i -e "s/%GRUB_UUID%/${GRUB_UUID}/g" "$MEMDISKDIR/grub.cfg"

# Ensure the old image is removed
    if [ -e "$CHROOTNAME/memdisk_img" ]; then
	$SUDO rm -f "$CHROOTNAME/memdisk_img"
    fi

# Create a memdisk img called memdisk_img
    cd "$WORKDIR" || exit
    tar cvf "$CHROOTNAME/memdisk_img" boot

# Make the image locally rather than rely on the grub2-rpm this allows more control as well as different images for IA32 if required
# To do this cleanly it's easiest to move the ISO directory containing the config files to the chroot, build and then move it back again
    $SUDO mv -f "$ISOROOTNAME" "$CHROOTNAME"

# Job done just remember to move it back again
    chroot "$CHROOTNAME"  /usr/bin/grub2-mkimage -O "$ARCHFMT" -d "$ARCHLIB" -m memdisk_img -o "/ISO/EFI/BOOT/$EFINAME" -p '(memdisk)/boot/grub' \
     search iso9660 normal memdisk tar boot linux part_msdos part_gpt part_apple configfile help loadenv ls reboot chain multiboot fat udf \
     ext2 btrfs ntfs reiserfs xfs lvm ata cat test echo multiboot multiboot2 all_video efifwsetup efinet font gfxmenu gfxterm gfxterm_menu \
     gfxterm_background gzio halt hfsplus jpeg mdraid09 mdraid1x minicmd part_apple part_msdos part_gpt part_bsd password_pbkdf2 png reboot \
     search search_fs_uuid search_fs_file search_label sleep tftp video xfs lua loopback regexp

# Move back the ISO filesystem after building the EFI image.
    $SUDO mv -f "$CHROOTNAME/ISO/" "$ISOROOTNAME"

# Ensure the ISO image is clear
    if [ -e "$CHROOTNAME/memdisk_img" ]; then
	$SUDO rm -f "$CHROOTNAME/memdisk_img"
    fi
}

createUEFI() {
# Usage: createEFI $EXTARCH $ISOCHROOTNAME
# Creates a fat formatted file in filesystem image which will boot an UEFI system.
# PLEASE NOTE THAT THE ISO DIRECTORY IS TEMPORARILY MOVED TO THE CHROOT DIRECTORY FOR THE PURPOSE OF GENERATING THE GRUB IMAGE.
    if [ $EXTARCH = "x86_64" ]; then
	ARCHFMT=x86_64-efi
	ARCHPFX=X64
    else
	ARCHFMT=i386-efi
	ARCHPFX=IA32
    fi
    ARCHLIB=/usr/lib/grub/"$ARCHFMT"
    EFINAME=BOOT"$ARCHPFX".efi
    printf "%s\n" "-> Setting up UEFI partiton and image." 

    IMGNME="$ISOROOTNAME/boot/grub/$EFINAME"
    GRB2FLS="$ISOROOTNAME"/EFI/BOOT

    printf "%s\n" "-> Building GRUB's EFI image." 
    if [ -e "$IMGNME" ]; then
	$SUDO rm -rf "$IMGNME"
    fi
    FILESIZE=$(du -s --block-size=512 "$ISOROOTNAME"/EFI | awk '{print $1}')
    EFIFILESIZE=$(( FILESIZE * 2 ))
    PARTTABLESIZE=$(( (2*17408)/512 ))
    EFIDISKSIZE=$((  $EFIFILESIZE + $PARTTABLESIZE + 1 ))

# Create the image.
    printf "%s\n" "-> Creating EFI image with size $EFIDISKSIZE" 

# mkfs.vfat can create the image and filesystem directly
    $SUDO mkfs.vfat -n "OPENMDVASS" -C -F 16 -s 1 -S 512 -M 0xFF -i 22222222 "$IMGNME" "$EFIDISKSIZE"
# Loopback mount the image
# IMPORTANT NOTE: In OMDV 4.x.x series kernels the loop driver is compiled as a module
# This causes problems when building in an ABF iso container.
# When the container is started if the the main kernel has not started the loop driver then
# no loop devices will be created in the docker isobuilder instance so the module must be loaded before 
# running losetup this is achieved by running "losetup -f" with no arguments.
# A further side effect is that if the module is loaded from inside docker when an image is mounted 
# on the docker loop device it is also mounted on ALL the available device names in the host OS thus
# making the loop devices unavailable to the main kernel though additional devices may be used in the docker instance.
# Yet another side effect is that the host OS automounts all the loop devices which then makes it impossible 
# to unmount them from inside the container. This problem can be overcome by adding the following rule to the docker-80.rules file

# The indentifiers in the files system image are used to ensure that the rule is unique to this script

    $SUDO losetup -f  > /dev/null 2>&1
    # Make sure loop device is loaded
    sleep 1
    $SUDO losetup -f "$IMGNME"
    if [[ $? != 0 ]]; then
	printf "%s\n" "-> Failed to mount loopback image." "Exiting."
	errorCatch
    fi
    sleep 1
    $SUDO mount -t vfat "$IMGNME" /mnt
    if [[ $? != 0 ]]; then
	printf "%s\n" "-> Failed to mount UEFI image." "Exiting."
	errorCatch
    fi

# Copy the Grub2 files to the EFI image
    $SUDO mkdir -p /mnt/EFI/BOOT
    $SUDO cp -R "$GRB2FLS"/"$EFINAME" /mnt/EFI/BOOT/"$EFINAME"

# Unmout the filesystem with EFI image
    $SUDO umount /mnt
# Be sure to delete the loop device
    $SUDO losetup -D 
# Make sure that the image is copied to the ISOROOT
    $SUDO cp -f  "$IMGNME" "$ISOROOTNAME"
# Clean up
    $SUDO kpartx -d "$IMGNME"
# Remove the EFI directory
    $SUDO rm -R "$ISOROOTNAME/EFI"
    XORRISO_OPTIONS2=" --efi-boot $EFINAME -append_partition 2 0xef $IMGNME"
    set +x
}

setupGrub2() {
# Usage: setupGrub2 (chroot directory (~/BASE) , iso directory (~/ISO), configdir (~/omdv-build-iso-<arch>)
# Sets up grub2 to boot /target/dir

    if [ ! -e "$CHROOTNAME"/usr/bin/grub2-mkimage ]; then
	printf "%s\n" "-> Missing grub2-mkimage in installation."
	errorCatch
    fi

# BIOS Boot and theme support
# NOTE Themes are used by the EFI boot as well.
# Copy grub config files to the ISO build directory
# and set the UUID's
    $SUDO cp -f "$WORKDIR"/grub2/grub2-bios.cfg "$ISOROOTNAME"/boot/grub/grub.cfg
    $SUDO sed -i -e "s/%GRUB_UUID%/${GRUB_UUID}/g" "$ISOROOTNAME"/boot/grub/grub.cfg
    $SUDO cp -f "$WORKDIR"/grub2/start_cfg "$ISOROOTNAME"/boot/grub/start_cfg
    printf "%s\n" "-> Setting GRUB_UUID to ${GRUB_UUID}"
    $SUDO sed -i -e "s/%GRUB_UUID%/${GRUB_UUID}/g" "$ISOROOTNAME"/boot/grub/start_cfg
    if [[ $? != 0 ]]; then
	    printf "%s\n" "-> Failed to set up GRUB_UUID."
	    errorCatch
	fi

# Add the themes, locales and fonts to the ISO build firectory
    if [ "${TYPE}" != "minimal" ]; then
	mkdir -p "$ISOROOTNAME"/boot/grub "$ISOROOTNAME"/boot/grub/themes "$ISOROOTNAME"/boot/grub/locale "$ISOROOTNAME"/boot/grub/fonts
	$SUDO cp -a -f "$CHROOTNAME"/boot/grub2/themes "$ISOROOTNAME"/boot/grub/
	$SUDO cp -a -f "$CHROOTNAME"/boot/grub2/locale "$ISOROOTNAME"/boot/grub/
	$SUDO cp -a -f "$CHROOTNAME"/usr/share/grub/*.pf2 "$ISOROOTNAME"/boot/grub/fonts/
	sed -i -e "s/title-text.*/title-text: \"Welcome to OpenMandriva Lx $VERSION ${EXTARCH} ${TYPE} BUILD ID: ${BUILD_ID}\"/g" "$ISOROOTNAME"/boot/grub/themes/OpenMandriva/theme.txt > /dev/null 2>&1

	if [[ $? != 0 ]]; then
	    printf "%s\n" "-> WARNING Failed to update Grub2 theme." "Please add a grub theme to my.add if needed."
#	    errorCatch
	fi
    fi
# Fix up 2014.0 grub installer line...We don't have Calamares in 2014.
    if [ "${VERSION,,}" == openmandriva2014.0 ]; then
    $SUDO sed -i -e "s/.*systemd\.unit=calamares\.target/ install/g" "$ISOROOTNAME"/boot/grub/start_cfg
    fi

    printf "%s\n" "-> Building Grub2 El-Torito image and an embedded image."

    GRUB_LIB=/usr/lib/grub/i386-pc
    GRUB_IMG=$(mktemp)

# Copy memtest
    $SUDO cp -rfT "$WORKDIR/extraconfig/memtest" "$ISOROOTNAME/boot/grub/memtest"
    $SUDO chmod +x "$ISOROOTNAME/boot/grub/memtest"
# To use an embedded image with our grub2 we need to make the modules available in the /boot/grub directory of the iso. The modules can't be carried in the payload of
# the embedded image as it's size is limited to 32kb. So we copy the i386-pc modules to the isobuild directory

    mkdir -p "$ISOROOTNAME/boot/grub/i386-pc"
    $SUDO cp -rf "$CHROOTNAME/usr/lib/grub/i386-pc" "$ISOROOTNAME/boot/grub/"

# Build the grub images in the chroot rather that in the host OS this avoids any issues with different versions of grub in the host OS especially when using local mode.
# this means cooker isos can be built on a local machine running a different version of OpenMandriva
# It requires that all the files needed to build the image must be within the chroot directory when the chroot command is invoked.
# Also we cannot write outside of the chroot so the images generated will remain in the chroot directory and will need to be removed before the squashfs is built
# these will be in /tmp and they are only small so leave them for the time being.
# If the entire ~/ISO director is copied to the chroot we do do have to worry too much about hacking the existing script to work
# with new paths we can simple add the $CHROOTNAME to the $ISOCHROOTNAME to get get the new path.
# So the quickest and easiest method is to mv the $ISOROOTNAME this avoids having two copies and is simple to understand
# First thoughmake sure we actually build new images
    if [ -e "$ISOROOTNAME/boot/grub/grub-eltorito.img" -o -e "$ISOROOTNAME/boot/grub/grub2-embed_img" ]; then
	$SUDO rm -rf "$ISOROOTNAME/boot/grub/{grub-eltorito,grub-embedded}.img"
    fi

    $SUDO mv -f "$ISOROOTNAME" "$CHROOTNAME"
# Job done just remember to move it back again
# Make the image
    $SUDO chroot "$CHROOTNAME" /usr/bin/grub2-mkimage -d "$GRUB_LIB" -O i386-pc -o "$GRUB_IMG" -p /boot/grub -c /ISO/boot/grub/start_cfg  iso9660 biosdisk test
# Move the ISO director back to the working directory
    $SUDO mv -f "$CHROOTNAME/ISO/" "$WORKDIR"
# Create bootable hard disk image
    $SUDO cat "$CHROOTNAME/$GRUB_LIB/boot.img" "$CHROOTNAME/$GRUB_IMG" > "$ISOROOTNAME/boot/grub/grub2-embed_img"
    if [[ $? != 0 ]]; then
	printf "%s\n" "-> Failed to create Grub2 El-Torito image." "Exiting."
	errorCatch
    fi
# Create bootable cdimage
    $SUDO cat "$CHROOTNAME/$GRUB_LIB/cdboot.img" "$CHROOTNAME/$GRUB_IMG" > "$ISOROOTNAME/boot/grub/grub2-eltorito.img"
    if [[ $? != 0 ]]; then
	printf  "%s\n" "-> Failed to create Grub2 El-Torito image." "Exiting."
	errorCatch
    fi

    XORRISO_OPTIONS1=" -b boot/grub/grub2-eltorito.img -no-emul-boot -boot-info-table --embedded-boot $ISOROOTNAME/boot/grub/grub2-embed_img --protective-msdos-label"

# Copy SuperGrub iso
# disable for now
#    $SUDO cp -rfT $OURDIR/extraconfig/super_grub2_disk_i386_pc_2.00s2.iso "$ISOROOTNAME"/boot/grub/sgb.iso

    printf "%s\n" "-> End building Grub2 El-Torito image."
    printf "%s\n" "-> Installing liveinitrd for grub2"

    if [ -e "$CHROOTNAME/boot/vmlinuz-$BOOT_KERNEL_ISO" ] && [ -e "$CHROOTNAME/boot/liveinitrd.img" ]; then
	$SUDO cp -a "$CHROOTNAME/boot/vmlinuz-$BOOT_KERNEL_ISO" "$ISOROOTNAME/boot/vmlinuz0"
	$SUDO cp -a "$CHROOTNAME/boot/liveinitrd.img" "$ISOROOTNAME/boot/liveinitrd.img"
    else
	printf "%s\n" "-> vmlinuz or liveinitrd does not exists. Exiting."
	errorCatch
    fi

    if [ ! -f "$ISOROOTNAME/boot/liveinitrd.img" ]; then
	printf "%s\n" "-> Missing /boot/liveinitrd.img. Exiting."
	errorCatch
    else
	$SUDO rm -rf "$CHROOTNAME/boot/liveinitrd.img"
    fi

    XORRISO_OPTIONS="$XORRISO_OPTIONS1 $XORRISO_OPTIONS2"
    $SUDO rm -rf "$GRUB_IMG"
}


setupISOenv() {
#set -x
# Set up default timezone
    printf "%s\n" "-> Setting default timezone"
    $SUDO ln -sf /usr/share/zoneinfo/Universal "$CHROOTNAME/etc/localtime"

# try harder with systemd-nspawn
# version 215 and never has then --share-system option
#	if (( `rpm -qa systemd --queryformat '%{VERSION} \n'` >= "215" )); then
#	    $SUDO systemd-nspawn --share-system -D "$CHROOTNAME" /usr/bin/timedatectl set-timezone UTC
#	    # set default locale
#	    printf "%sSetting default localization"
#	    $SUDO systemd-nspawn --share-system -D "$CHROOTNAME" /usr/bin/localectl set-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8:en_US:en
#	else
#	    printf "%ssystemd-nspawn does not exists."
#	fi

# Create /etc/minsysreqs
    printf "%s\n" "-> Creating /etc/minsysreqs"

    if [ "${TYPE,,}" = "minimal" ]; then
	echo "ram = 512" >> "$CHROOTNAME/etc/minsysreqs"
	echo "hdd = 5" >> "$CHROOTNAME/etc/minsysreqs"
    elif [ "$EXTARCH" = "x86_64" ]; then
	echo "ram = 1536" >> "$CHROOTNAME/etc/minsysreqs"
	echo "hdd = 10" >> "$CHROOTNAME/etc/minsysreqs"
    else
	echo "ram = 1024" >> "$CHROOTNAME/etc/minsysreqs"
	echo "hdd = 10" >> "$CHROOTNAME/etc/minsysreqs"
    fi

# Count imagesize and put in in /etc/minsysreqs
    $SUDO echo "imagesize = $(du -a -x -b -P "$CHROOTNAME" | tail -1 | awk '{print $1}')" >> "$CHROOTNAME"/etc/minsysreqs

# Set up displaymanager
    if [[ ( ${TYPE,,} != "minimal" || ${TYPE,,} != "my.add" ) && ! -z ${DISPLAYMANAGER,,} ]]; then
	if [ ! -e "$CHROOTNAME/lib/systemd/system/${DISPLAYMANAGER,,}.service" ]; then
	    printf "%s\n" "-> File ${DISPLAYMANAGER,,}.service does not exist. Exiting."
	    errorCatch
	fi

	$SUDO ln -sf "/lib/systemd/system/${DISPLAYMANAGER,,}.service" "$CHROOTNAME/etc/systemd/system/display-manager.service" 2> /dev/null || :

# Set reasonable defaults


	if  [ -e "$CHROOTNAME/etc/sysconfig/desktop" ]; then
	    $SUDO rm -rf "$CHROOTNAME"/etc/sysconfig/desktop
	fi

# Create very important desktop file
    cat >"$CHROOTNAME"/etc/sysconfig/desktop <<EOF
DISPLAYMANAGER=$DISPLAYMANAGER
DESKTOP=$TYPE
EOF

    fi

# Copy some extra config files
    $SUDO cp -rfT "$WORKDIR/extraconfig/etc" "$CHROOTNAME"/etc/
    $SUDO cp -rfT "$WORKDIR/extraconfig/usr" "$CHROOTNAME"/usr/

# Set up live user
    live_user=live
    printf "%s\n" "-> Setting up user ${live_user}"
    $SUDO chroot "$CHROOTNAME" /usr/sbin/adduser -m -G wheel ${live_user}

# Clear user passwords
    for username in root $live_user; do
# Kill it as it prevents clearing passwords
	if [ -e "$CHROOTNAME"/etc/shadow.lock ]; then
	    $SUDO rm -rf "$CHROOTNAME"/etc/shadow.lock
	fi
	printf "%s\n" "-> Clearing $username password."
	$SUDO chroot "$CHROOTNAME" /usr/bin/passwd -f -d $username

	if [[ $? != 0 ]]; then
	    printf "%s\n" "-> Failed to clear $username user password." "Exiting."
	    errorCatch
	fi

	$SUDO chroot "$CHROOTNAME" /usr/bin/passwd -f -u $username
    done

    $SUDO chroot "$CHROOTNAME" /bin/mkdir -p /home/${live_user}
    $SUDO chroot "$CHROOTNAME" /bin/cp -rfT /etc/skel /home/${live_user}/
    $SUDO chroot "$CHROOTNAME" /bin/mkdir -p /home/${live_user}/Desktop
    $SUDO cp -rfT "$WORKDIR"/extraconfig/etc/skel "$CHROOTNAME"/home/${live_user}/
    $SUDO chroot "$CHROOTNAME" /bin/mkdir -p /home/${live_user}/.cache
    $SUDO chroot "$CHROOTNAME" /bin/chown -R ${live_user}:${live_user} /home/${live_user}
    $SUDO chroot "$CHROOTNAME" /bin/chown -R ${live_user}:${live_user} /home/${live_user}/Desktop
    $SUDO chroot "$CHROOTNAME" /bin/chown -R ${live_user}:${live_user} /home/${live_user}/.cache
    $SUDO chroot "$CHROOTNAME" /bin/chmod -R 0777 /home/${live_user}/.local
# (tpg) support for AccountsService
    $SUDO chroot "$CHROOTNAME" /bin/mkdir -p /var/lib/AccountsService/users
    $SUDO chroot "$CHROOTNAME" /bin/mkdir -p /var/lib/AccountsService/icons
    $SUDO cp -f "$WORKDIR"/data/account-user "$CHROOTNAME"/var/lib/AccountsService/users/${live_user}
    $SUDO cp -f "$WORKDIR"/data/account-icon "$CHROOTNAME"/var/lib/AccountsService/icons/${live_user}
    $SUDO chroot "$CHROOTNAME" /bin/sed -i -e "s/_NAME_/${live_user}/g" /var/lib/AccountsService/users/${live_user}

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
	$SUDO rm -rf "$CHROOTNAME"/home/${live_user}/.kde4
    fi

# Enable DM autologin
    if [ "${TYPE,,}" != "minimal" ]; then
	case ${DISPLAYMANAGER,,} in
		"kdm")
		    $SUDO chroot "$CHROOTNAME" sed -i -e 's/.*AutoLoginEnable.*/AutoLoginEnable=True/g' -e 's/.*AutoLoginUser.*/AutoLoginUser=live/g' /usr/share/config/kdm/kdmrc
		    ;;
		"sddm")
		    $SUDO chroot "$CHROOTNAME" sed -i -e "s/^Session=.*/Session=${TYPE,,}.desktop/g" -e 's/^User=.*/User=live/g' /etc/sddm.conf
		    if [ "${TYPE,,}" = "lxqt" ]; then
# (tpg) use maldives theme on LXQt desktop
			$SUDO chroot "$CHROOTNAME" sed -i -e "s/^Current=.*/Current=maldives/g" /etc/sddm.conf
		    fi
		    ;;
		"gdm")
		    $SUDO chroot "$CHROOTNAME" sed -i -e "s/^AutomaticLoginEnable.*/AutomaticLoginEnable=True/g" -e 's/^AutomaticLogin.*/AutomaticLogin=live/g' /etc/X11/gdm/custom.conf
		    ;;
		*)
		    printf "%s -> ${DISPLAYMANAGER,,} is not supported, autologin feature will be not enabled"
	esac
    fi

    $SUDO pushd "$CHROOTNAME"/etc/sysconfig/network-scripts > /dev/null 2>&1
    for iface in eth0 wlan0; do
	cat > ifcfg-$iface << EOF
DEVICE=$iface
ONBOOT=yes
NM_CONTROLLED=yes
BOOTPROTO=dhcp
EOF
    done
    $SUDO popd > /dev/null 2>&1

    printf "%s\n" "-> Starting services setup."

# (tpg) enable services based on preset files from systemd and others
    UNIT_DIR="$CHROOTNAME"/lib/systemd/system
    if [ -f "$UNIT_DIR-preset/90-default.preset" ]; then
	PRESETS=($UNIT_DIR-preset/*.preset)
	for file in "${PRESETS[@]}"; do
	    while read line; do
		if [[ -n "$line" && "$line" != [[:blank:]#]* && "${line,,}" = [[:blank:]enable]* ]]; then
		    SANITIZED="${line#*enable}"
		    for s_file in $(find "$UNIT_DIR" -type f -name "$SANITIZED"); do
			    DEST=$(grep -o 'WantedBy=.*' "$s_file"  | cut -f2- -d'=')
			if [ -n "$DEST" ] && [ -d "$CHROOTNAME/etc/systemd/system" ] && [ ! -e "$CHROOTNAME/etc/systemd/system/$DEST.wants/${s_file#$UNIT_DIR/}" ] ; then
			    [[ ! -d "/etc/systemd/system/$DEST.wants" ]] && mkdir -p "$CHROOTNAME/etc/systemd/system/$DEST.wants"
			    printf "%s\n" "-> Enabling ${s_file#$UNIT_DIR/}"
			    #/bin/systemctl --quiet enable ${s#$UNIT_DIR/};
			    ln -sf "/${s_file#$CHROOTNAME/}" "$CHROOTNAME/etc/systemd/system/$DEST.wants/${s_file#$UNIT_DIR/}"
			fi
		    done
		fi
	    done < "$file"
	done
    else
	printf "%s\n" "-> File $UNIT_DIR-preset/90-default.preset does not exist. Installation is broken"
	errorCatch
    fi


# Enable services on demand
    SERVICES_ENABLE=(getty@tty1.service sshd.socket irqbalance smb nmb winbind systemd-timesyncd)

    for i in "${SERVICES_ENABLE[@]}"; do
	if [[ $i  =~ ^.*socket$|^.*path$|^.*target$|^.*timer$ ]]; then
	    if [ -e "$CHROOTNAME/lib/systemd/system/$i" ]; then
		printf "%s\n" "-> Enabling $i"
		ln -sf "/lib/systemd/system/$i" "$CHROOTNAME/etc/systemd/system/multi-user.target.wants/$i"
	    else
		printf "%s\n" "-> Special service $i does not exist. Skipping."
		fi
	elif [[ ! $i  =~ ^.*socket$|^.*path$|^.*target$|^.*timer$ ]]; then
	    if [ -e "$CHROOTNAME/lib/systemd/system/$i.service" ]; then
		printf "%s\n" "-> Enabling $i.service"
		ln -sf "/lib/systemd/system/$i.service" "$CHROOTNAME/etc/systemd/system/multi-user.target.wants/$i.service"
	    else
		printf "%s\n" "-> Service $i does not exist. Skipping."
	    fi
	else
	    printf "%s\n" "-> Wrong service match."
	fi
    done

# Disable services
    SERVICES_DISABLE=(pptp pppoe ntpd iptables ip6tables shorewall nfs-server mysqld abrtd mariadb mysql mysqld postfix NetworkManager-wait-online chronyd)

    for i in "${SERVICES_DISABLE[@]}"; do
	if [[ $i  =~ ^.*socket$|^.*path$|^.*target$|^.*timer$ ]]; then
	    if [ -e "$CHROOTNAME/lib/systemd/system/$i" ]; then
		printf "%s\n" "-> Disabling $i"
		$SUDO rm -rf "$CHROOTNAME/etc/systemd/system/multi-user.target.wants/$i"
	    else
		printf "%s\n" "-> Special service $i does not exist. Skipping."
	    fi
	elif [[ ! $i  =~ ^.*socket$|^.*path$|^.*target$|^.*timer$ ]]; then
	    if [ -e "$CHROOTNAME/lib/systemd/system/$i.service" ]; then
		printf "%s\n" "-> Disabling $i.service"
		$SUDO rm -rf "$CHROOTNAME/etc/systemd/system/multi-user.target.wants/$i.service"
	    else
		printf "%s\n" "-> Service $i does not exist. Skipping."
	    fi

	else
	    printf "%s\n" "-> Wrong service match."
	fi
    done

# mask systemd-journald-audit.socket to stop polluting journal with audit spam
    [[ ! -e "$CHROOTNAME"/etc/systemd/system/systemd-journald-audit.socket ]] && ln -sf /dev/null "$CHROOTNAME"/etc/systemd/system/systemd-journald-audit.socket

# ATTENTION getty@.service must be always disabled
    [[ -e "$CHROOTNAME"/etc/systemd/system/getty.target.wants/getty@.service ]] && rm -rf "$CHROOTNAME"/etc/systemd/system/getty.target.wants/getty@.service

# Calamares installer
    if [ -e "$CHROOTNAME"/etc/calamares/modules/displaymanager.conf ]; then

# Enable settings for specific desktop environment
# https://issues.openmandriva.org/show_bug.cgi?id=1424
	sed -i -e "s/.*defaultDesktopEnvironment:.*/defaultDesktopEnvironment:/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"

	if [ "${TYPE,,}" = "plasma" ]; then
	    sed -i -e "s/.*executable:.*/executable: "startkde"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.con"f
	    sed -i -e "s/.*desktopFile:.*/desktopFile: "plasma"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
	fi

	if [ "${TYPE,,}" = "kde4" ]; then
	    sed -i -e "s/.*executable:.*/executable: "startkde"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
	    sed -i -e "s/.*desktopFile:.*/desktopFile: "kde-plasma"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
	fi

	if [ "${TYPE,,}" = "mate" ]; then
	    sed -i -e "s/.*executable:.*/executable: "mate-session"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
	    sed -i -e "s/.*desktopFile:.*/desktopFile: "mate"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
	fi

	if [ "${TYPE,,}" = "lxqt" ]; then
	    sed -i -e "s/.*executable:.*/executable: "lxqt-session"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
	    sed -i -e "s/.*desktopFile:.*/desktopFile: "lxqt"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
	fi

	if [ "${TYPE,,}" = "icewm" ]; then
	    sed -i -e "s/.*desktopFile:.*/desktopFile: "icewm"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
	fi

	if [ "${TYPE,,}" = "xfce4" ]; then
	    sed -i -e "s/.*executable:.*/executable: "startxfce4"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
	    sed -i -e "s/.*desktopFile:.*/desktopFile: "xfce"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
	fi

    fi
#    if [ -e "$CHROOTNAME"/etc/calamares/modules/unpackfs.conf ]; then
#	echo "Updating calamares settings."
	# update patch to squashfs
#	$SUDO sed -i -e "s#source:.*#source: "/media/$LABEL/LiveOS/squashfs.img"#" "$CHROOTNAME"/etc/calamares/modules/unpackfs.conf
#    fi

    #remove rpm db files which may not match the non-chroot environment
    $SUDO chroot "$CHROOTNAME" rm -f /var/lib/rpm/__db.*
# Fix Me This should be a function
# FIX ME There should be a fallback to abf-downloads here or perhaps to a primary mirror.
    if [ -z "$NOCLEAN" ]; then
# add urpmi medias inside chroot
	printf "%s\n" "-> Removing old urpmi repositories."
	$SUDO urpmi.removemedia -a --urpmi-root "$CHROOTNAME"
    printf "%s\n" "-> Adding new urpmi repositories."
	if [ "${TREE,,}" = "cooker" ]; then
	    MIRRORLIST="http://downloads.openmandriva.org/mirrors/cooker.$EXTARCH.list"

	    $SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" --wget --no-md5sum --mirrorlist "$MIRRORLIST" 'Main' 'media/main/release'
	    if [[ $? != 0 ]]; then
		$SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" --wget --no-md5sum 'Main' http://abf-downloads.openmandriva.org/"${TREE,,}"/repository/"${EXTARCH}"/main/release
	    fi

# Add 32-bit main repository for non i586 build
	    if [ "$EXTARCH" = "x86_64" ]; then
		printf "%s\n" "-> Adding 32-bit media repository."
# Use previous MIRRORLIST declaration but with i586 arch in link name
        MIRRORLIST2="$(echo "$MIRRORLIST" | sed -e "s/x86_64/i586/g")"
		$SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" --wget --no-md5sum --mirrorlist "$MIRRORLIST2" 'Main32' 'media/main/release'
		if [[ $? != 0 ]]; then
		$SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" --wget --no-md5sum 'Main32' http://abf-downloads.openmandriva.org/"${TREE,,}"/repository/i586/main/release
		    if [[ $? != 0 ]]; then
			printf "%s\n" "-> Adding urpmi 32-bit media FAILED. Exiting"
			errorCatch
		    fi
		fi
	    fi

	    $SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" --wget --no-md5sum --mirrorlist "$MIRRORLIST" 'Contrib' 'media/contrib/release'
	    if [[ $? != 0 ]]; then
		$SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" --wget --no-md5sum 'Contrib' http://abf-downloads.openmandriva.org/"${TREE,,}"/repository/"${EXTARCH}"/contrib/release
	    fi
# This one is needed to grab firmwares
	    $SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" --wget --no-md5sum --mirrorlist "$MIRRORLIST" 'Non-free' 'media/non-free/release'
	    if [[ $? != 0 ]]; then
		$SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" --wget --no-md5sum 'Non-Free' http://abf-downloads.openmandriva.org/"${TREE,,}"/repository/"${EXTARCH}"/non-free/release
	    fi
	else
	    MIRRORLIST="http://downloads.openmandriva.org/mirrors/openmandriva.${TREE##openmandriva}.$EXTARCH.list"
	    printf "%s -> Using $MIRRORLIST"
	    $SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" --wget --no-md5sum --distrib --mirrorlist $MIRRORLIST
	    if [[ $? != 0 ]]; then
		printf "%s\n" "-> Adding urpmi media FAILED. Falling back to use ABF."
		$SUDO urpmi.addmedia --urpmi-root "$CHROOTNAME" --wget --no-md5sum --distrib --mirrorlist http://abf-downloads.openmandriva.org/${TREE##openmandriva}.${EXTARCH}.list
		if [[ $? != 0 ]]; then
		    printf "%s" "-> Adding urpmi media FAILED. Exiting."
		    errorCatch
		fi
	    fi
	fi

# Update urpmi medias
	printf "%s" "-> Updating urpmi repositories"
	$SUDO urpmi.update --urpmi-root "$CHROOTNAME" -a -ff --wget --force-key
    fi # noclean

# Get back to real /etc/resolv.conf
    $SUDO rm -f "$CHROOTNAME"/etc/resolv.conf
    if [ "$(cat "$CHROOTNAME/etc/release" | grep -o 2014.0)" == "2014.0" ]; then
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
        # set the timestamp on the directories to be a whole second
        # fc-cache looks at the nano second portion which will otherwise be
        # non-zero as we are on ext4, but then it will compare against the stamps
        # on the squashfs live image, squashfs only has second level timestamp resolution
        FCTIME=$(date +%Y%m%d%H%M.%S)
        $SUDO chroot "$CHROOTNAME" find /usr/share/fonts -type d -exec touch -t "$FCTIME" {} \;
	$SUDO chroot "$CHROOTNAME" fc-cache -rf
	$SUDO chroot "$CHROOTNAME" /bin/mkdir -p /root/.cache/fontconfig/
	$SUDO chroot "$CHROOTNAME" /bin/mkdir -p /${live_user}/.cache/fontconfig/
    fi

# Rebuild man-db
    if [ -x "$CHROOTNAME"/usr/bin/mandb ]; then
    printf "%s\n" "-> Please wait...rebuilding man page database"
    	$SUDO chroot "$CHROOTNAME" /usr/bin/mandb --quiet
    fi

# Rebuild linker cache
    $SUDO chroot "$CHROOTNAME" /sbin/ldconfig

# Clear tmp
    $SUDO rm -rf "$CHROOTNAME"/tmp/*

# Clear urpmi cache
    if [[ ("$IN_ABF" == "0" || ( "$IN_ABF" == "1" && -n "$DEBUG" )) ]]; then
# Move contents of rpm cache away so as not to include in iso
	$SUDO mv "$CHROOTNAME/var/cache/urpmi/rpms" "$WORKDIR/rpms"
# Remake original directory	
	$SUDO mkdir -m 755 -p  "$CHROOTNAME"/var/cache/urpmi/rpms
    else
    	$SUDO rm -rf "$CHROOTNAME"/var/cache/urpmi/partial/*
    	$SUDO rm -rf "$CHROOTNAME"/var/cache/urpmi/rpms/*
    fi
# Generate list of installed rpm packages
    $SUDO chroot "$CHROOTNAME" rpm -qa --queryformat="%{NAME}\n" | sort > /var/lib/rpm/installed-by-default

# Remove rpm db files to save some space
    $SUDO rm -rf "$CHROOTNAME"/var/lib/rpm/__db.*
#
 $SUDO echo 'File created by omdv-build-iso. See systemd-update-done.service(8).' \
    | tee "$CHROOTNAME"/etc/.updated >"$CHROOTNAME"/var/.updated

}

createSquash() {
    printf "%s\n" "-> Starting squashfs image build."
# Before we do anything check if we are a local build
    if [ "$IN_ABF" == "0" ]; then
# We are so make sure that nothing is mounted on the chroots /run/os-prober/dev/ directory.
# If mounts exist mksquashfs will try to build a squashfs.img with contents of all  mounted drives
# It's likely that the img will be written to one of the mounted drives so it's unlikely
# that there will be enough diskspace to complete the operation.
	if [ -f "$ISOROOTNAME/run/os-prober/dev/*" ]; then
		$SUDO umount -l "$(echo "$ISOROOTNAME/run/os-prober/dev/*")"
	    if [ -f "$ISOROOTNAME/run/os-prober/dev/*" ]; then
		printf "%s\n" "-> Cannot unount os-prober mounts aborting."
		errorCatch
	    fi
	fi
    fi

    if [ -f "$ISOROOTNAME"/LiveOS/squashfs.img ]; then
	$SUDO rm -rf "$ISOROOTNAME"/LiveOS/squashfs.img
    fi

    mkdir -p "$ISOROOTNAME"/LiveOS
# Unmout all stuff inside CHROOT to build squashfs image
    umountAll "$CHROOTNAME"

# Here we go with local speed ups
# For development only remove all the compression so the squashfs builds quicker.
# Give it it's own flag QUICKEN.
    if [ -n "$QUICKEN" ]; then
	$SUDO mksquashfs "$CHROOTNAME" "$ISOROOTNAME"/LiveOS/squashfs.img -comp ${COMPTYPE} -no-progress -noD -noF -noI -no-exports -no-recovery -b 16384
    else
	$SUDO mksquashfs "$CHROOTNAME" "$ISOROOTNAME"/LiveOS/squashfs.img -comp ${COMPTYPE}  -no-progress -no-exports -no-recovery -b 16384
    fi
    if [ ! -f  "$ISOROOTNAME"/LiveOS/squashfs.img ]; then
	printf "%s\n" "-> Failed to create squashfs." "Exiting."
	errorCatch
    fi

}

buildIso() {
# Usage: buildIso filename.iso rootdir
# Builds an ISO file from the files in rootdir

    printf "%s\n" "-> Starting ISO build."

    if [ "$IN_ABF" == "1" ]; then
	ISOFILE="$WORKDIR/$PRODUCT_ID.$EXTARCH.iso"
    else
	if [ -z "$OUTPUTDIR" ]; then
	ISOFILE="$WORKDIR/$PRODUCT_ID.$EXTARCH.iso"
	else
	ISOFILE="$OUTPUTDIR/$PRODUCT_ID.$EXTARCH.iso"
	fi
    fi

    if [ ! -x /usr/bin/xorriso ]; then
	printf "%s/n" "-> xorriso does not exists. Exiting."
	errorCatch
    fi

# Before starting to build remove the old iso. xorriso is much slower to create an iso.
# if it is overwriting an earlier copy. Also it's not clear whether this affects the.
# contents or structure of the iso (see --append-partition in the man page)
# Either way building the iso is 30 seconds quicker (for a 1G iso) if the old one is deleted.
    if [[ "$IN_ABF" == "0" && -n "$ISOFILE" ]]; then
	printf "%s" "-> Removing old iso."
	$SUDO rm -rf "$ISOFILE"
    fi
    printf "%s\n" "-> Building ISO with options ${XORRISO_OPTIONS}"

    $SUDO xorriso -as mkisofs -R -r -J -joliet-long -cache-inodes \
	-graft-points -iso-level 3 -full-iso9660-filenames \
	--modification-date="${ISO_DATE}" \
	-omit-version-number -disable-deep-relocation \
	${XORRISO_OPTIONS} \
	-publisher "OpenMandriva Association" \
	-preparer "OpenMandriva Association" \
	-volid "$LABEL" -o "$ISOFILE" "$ISOROOTNAME" --sort-weight 0 / --sort-weight 1 /boot

    if [ ! -f "$ISOFILE" ]; then
	printf "%s\n" "-> Failed build iso image." "Exiting"
	errorCatch
    fi

    printf "%s\n" "-> ISO build completed."
}

postBuild() {
    if [ ! -f "$ISOFILE" ]; then
	umountAll "$CHROOTNAME"
	errorCatch
    fi

# Count checksums
	printf "%s\n" "-> Generating ISO checksums."
	if [ -n "$OUTPUTDIR" ]; then
        $SUDO cd "$OUTPUTDIR"
        md5sum "$PRODUCT_ID.$EXTARCH.iso" > "$PRODUCT_ID.$EXTARCH.iso.md5sum"
        sha1sum "$PRODUCT_ID.$EXTARCH.iso" > "$PRODUCT_ID.$EXTARCH.iso.sha1sum"
        else
        pushd "$WORKDIR" > /dev/null 2>&1
        md5sum "$PRODUCT_ID.$EXTARCH.iso" > "$PRODUCT_ID.$EXTARCH.iso.md5sum"
        sha1sum "$PRODUCT_ID.$EXTARCH.iso" > "$PRODUCT_ID.$EXTARCH.iso.sha1sum"
        popd > /dev/null 2>&1
    fi
	$SUDO mkdir -p "$WORKDIR/results" "$WORKDIR/archives"
	if [ -n "$OUTPUTDIR" ]; then
        $SUDO mv "$OUTPUTDIR"/*.iso* "$WORKDIR/results/"
	else
        $SUDO mv "$WORKDIR"/*.iso* "$WORKDIR/results/"
	fi
	if [[ "$IN_ABF" == "0"  || ( "$IN_ABF" == "1" && -n "$DEBUG" && -n "$DEVMODE" ) ]]; then
	$SUDO cp -r "$WORKDIR"/sessrec/ "$WORKDIR/archives/"
	fi


# If not in ABF move rpms back to the cache directories
    if [[ ("$IN_ABF" == "0" || ( "$IN_ABF" == "1" && -n "$DEBUG" )) ]]; then
        $SUDO mv -f "$WORKDIR"/rpms "$CHROOTNAME"/var/cache/urpmi/
    fi

# Clean chroot
    umountAll "$CHROOTNAME"
}

main "$@"




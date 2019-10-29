#!/bin/bash
#set -x
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
# April 2018 Major Revision to support the use of the
# dnf which replaces urpmi: Colin Close <itchka@compuserve.com>
# October 2019 Revise user mode list storage <itchka@compuserve.com>

# This tool is licensed under GPL license
#	This program is free software; you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation; either version 2 of the License, or
#	(at your option) any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with this program; if not, write to the Free Software
#	Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#

# This tool is specified to build OpenMandriva Lx distribution ISO

main() {
	# This function which starts at the top of the file is executed first from the end of file
	# to ensure that all functions are read before the body of the script is run.
	# All global variables need to be inside the curly braces of this function.

	# Make sure MAXERRORS gets preset to a real number else parallel will error out.
	# This will be overidden by the users value if given.
	MAXERRORS=1


	if [ "$#" -lt 1 ]; then
		usage_help
		exit 1
	fi

	for k in "$@"; do
		case "$k" in
		--arch=*)
			EXTARCH=${k#*=}
			;;
		--tree=*)
			TREE=${k#*=}
			case "$TREE" in
			lx4)
				TREE=4.0
				;;
			*)
				TREE="$TREE"
				;;
			esac
			;;
		--version=*)
			VERSION=${k#*=}
			if [[ "${VERSION,,}" = 'cooker' ]]; then
				VERSION="$(date +%Y.0)"
			fi
			;;
		--release_id=*)
			RELEASE_ID=${k#*=}
			;;
		--boot-kernel-type=*)
			BOOT_KERNEL_TYPE=${k#*=}
			;;
		--type=*)
			declare -l lc
			lc=${k#*=}
			case "$lc" in
			plasma)
				TYPE=plasma
				;;
			plasma-wayland)
				TYPE=plasma-wayland
				;;
			mate)
				TYPE=mate
				;;
			lxqt)
				TYPE=lxqt
				;;
			icewm)
				TYPE=icewm
				;;
			xfce4)
				TYPE=xfce4
				;;
			weston)
				TYPE=weston
				;;
            gnome3)
                TYPE=gnome3
                ;;
			minimal)
				TYPE=minimal
				;;
			sway)
				TYPE=sway
				;;
            mate)
                TYPE=mate
                ;;
			user)
				TYPE=my.add
				;;
			*)
				printf "%s\n" "$TYPE is not supported."
				usage_help
				;;
			esac
			;;
		--displaymanager=*)
			DISPLAYMANAGER=${k#*=}
			;;
		--workdir=*)
			WORK=${k#*=}
			# Expand the tilde
			WORKDIR=${WORK/#\~/$HOME}
			;;
		--outputdir=*)
			OUTPUT=${k#*=}
			# Expand the tilde
			OUTPUTDIR=${OUTPUT/#\~/$HOME}
			;;
		--listrepodir=*)
			REPO=${k#*=}
			# Expand the tilde
			LREPODIR=${REPO/#*\~/$HOME}
			;;
		--debug)
			DEBUG=debug
			;;
		--noclean)
			NOCLEAN=noclean
			;;
		--rebuild)
			REBUILD=rebuild
			;;
		 --quicken)
			QUICKEN=squashfs
			;;
		 --compressor=*)
			declare -l lcmp
			lcmp=${k#*=}
                case "$lcmp" in
                    gzip)
            		COMPTYPE=gzip
            		;;
            		gz)
            		COMPTYPE=gz
            		;;
            		lzo)
            		COMPTYPE=lzo
            		;;
            		lz4)
            		COMPTYPE=lz4
            		;;
            		xz)
            		COMPTYPE=xz
            		;;
            		zstd)
            		COMPTYPE=zstd
            		;;
            		*)
            		 printf "%s\n" "Error: Illegal compressor name"
            		 printf "%s\n" "Using default zstd"
            		 COMPTYPE=zstd
            		 exit
            		;;
            	esac
            ;;	
		 --keep)
			KEEP=keep
			;;
		 --testrepo)
			TESTREPO=testrepo
			;;
		 --unsupprepo)
			UNSUPPREPO=unsupprepo
			;;
		 --repolist=*)
			ENABLEREPO=${k#*=}
			;;
        --baserepo)
            BASEREPO=baserepo
            ;;
		 --parallel)
			PLLL=plll
			;;
		 --isover=*)
			ISO_VER=${k#*=}
			;;
		 --maxerrors=*)
			MAXERRORS=${k#*=}
			;;
		 --devmode)
			DEVMODE=devmode
			;;
		 --auto-update)
			AUTO_UPDATE=1
			;;
         --usemirrors)
            USEMIRRORS=usemirrors
            ;;
        --makelistrepo)
            MAKELISTREPO=makelistrepo
            ;;
		 --help)
			usage_help
			;;
		*)
			echo "Unknown argument $k" >/dev/stderr
			usage_help
			exit 1
			;;
		esac
	done

	# Locales aren't installed in the chroot yet (obviously), don't spew errors about that
	export LANG=C
	export LC_ALL=C

	# We lose our cli variables when we invoke sudo so we save them
	# and pass them to sudo when it is started. Also the user name is needed.
	# The abf isobuilder docker instance is created with a single working directory /home/omv/iso_builder.
	# This directory must not be deleted as it contains important (but hidden) config files.
	# A support directory /home/omv/docker-iso-worker is also created this should also not be touched.
	# When an iso build request is generated from ABF the script commandline along with the data from the git repo
	# for the named branch of the script is loaded into the /home/omv/iso_builder directory and the script executed
	# from that directory. If the build completes without error a directory /home/omv/iso_builder/results is created
	# and the completed iso along with it's md5 and sha1 checksums are moved to it. These files are eventually uploaded
	# to abf for linking and display on the build results webpage. If the results are placed anywhere else they are not displayed.

	SUDOVAR=""EXTARCH="$EXTARCH "TREE="$TREE "VERSION="$VERSION "RELEASE_ID="$RELEASE_ID "TYPE="$TYPE \ "DISPLAYMANAGER="$DISPLAYMANAGER "DEBUG="$DEBUG "NOCLEAN="$NOCLEAN "REBUILD="$REBUILD \ 
	"WORKDIR="$WORKDIR "OUTPUTDIR="$OUTPUTDIR "ISO_VER="$ISO_VER "ABF="$ABF "QUICKEN="$QUICKEN \ 
	"COMPTYPE="$COMPTYPE "KEEP="$KEEP "TESTREPO="$TESTREPO "UNSUPPREPO="$UNSUPPREPO "ENABLEREPO="$ENABLEREPO \ 
	"AUTO_UPDATE="$AUTO_UPDATE "DEVMODE="$DEVMODE "ENSKPLST="$ENSKPLST "PLLL="$PLLL "MAXERRORS="$MAXERRORS \ 
	"LREPODIR="$LREPODIR "USEMIRRORS="$USEMIRRORS "BASEREPO="$BASEREPO "MAKELISTREPO="$MAKELISTREPO "

	# run only when root
	if [ "$(id -u)" != '0' ]; then
		# We need to be root for umount and friends to work...
		# NOTE the following command will only work on OMDV for the first registered user
		# this user is a member of the wheel group and has root privelidges
		exec sudo -E $(echo ${SUDOVAR}) $0 "$@"
		printf "%s\n" "-> Run me as root."
		exit 1
	fi

	if [ -n "$DEBUG" ]; then
        set -x
    else
        set +x
    fi
	# Set the local build prefix
	if [ -d /home/omv ] && [ -d '/home/omv/docker-iso-worker' ]; then
		WHO=omv
	else
		# SUDO_USER is an environment variable from the shell it gets set if you run as sudo
		WHO="$SUDO_USER"
		UHOME=/home/"$WHO"
		export UHOME
	fi

	# default definitions
	DIST=omdv
	[ -z "$EXTARCH" ] && EXTARCH="$(rpm -E '%{_target_cpu}')"
	[ -z "$EXTARCH" ] && EXTARCH="$(uname -m)"
	[ -z "${TREE}" ] && TREE=cooker
	[ -z "${VERSION}" ] && VERSION="$(date +%Y.0)"
	[ -z "${RELEASE_ID}" ] && RELEASE_ID=alpha
	[ -z "${COMPTYPE}" ] && COMPTYPE="zstd -Xcompression-level 15"
	[ -z "${MAXERRORS}" ] && MAXERRORS=1

	ARCHEXCLUDE=""
	echo $EXTARCH |grep -qE "^arm" && EXTARCH=armv7hnl
	echo $EXTARCH |grep -qE "i.86" && EXTARCH=i686

	# Exclude 32-bit compat packages on multiarch capable systems
	case $EXTARCH in
	znver1|x86_64)
		ARCHEXCLUDE='--exclude=*.i686'
		;;
	aarch64)
		ARCHEXCLUDE='--exclude=*.armv7hnl'
		;;
	esac

	# always build free ISO
	FREE=1
	LOGDIR="."
	if [ -z $ABF ]; then
		IN_ABF='0'
	fi
	
mkeUsrListRepo () {	
	if [ IN_ABF='0' ]; then
        if [ -n "$MAKELISTREPO" ] && [ -n "$LREPODIR" ]; then
            mkeREPOdir
            getPkgList
            MkeListRepo
            DtctCmmt
            printf "%s\n" "Created local user list repo $LREPODIR" 
        fi
    fi
    exit 0
}
	
	allowedOptions
	setWorkdir

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

 if [ "$IN_ABF" = '0' ]; then
    if [ -n "$NOCLEAN" ] && [ -d "$WORKDIR" ]; then #if NOCLEAN option selected then retain the chroot.
		if [ ! -d "$COMMITDIR"/sessrec ]; then 
            touch "$WORKDIR"/.new
        else
			printf "%s\n" "-> You have chosen not to clean the base installation" \
				"If your build chroot becomes corrupted you may want"\
				"to take advantage of the 'rebuild' option to delete the corrupted files"\
				"and build a new base installation." \
				"This will be faster than dowloading the rpm packages again"
        # The .new file will have been removed restore it for the next build.
            touch "$WORKDIR"/.new
		fi
		# Note need to clean out grub uuid files here and maybe others
    else
        if [ -n "$REBUILD" ] && [ ! -d "$WORKDIR" ]; then
            printf "%s\n" "-> Error the $WORKDIR does not exist there is nothing to rebuild." \
            "-> You must run  your command with the --noclean option set to create something to rebuild."
            printf "%s\n" "-> No base chroot exists...creating one"
            RemkWorkDir
        elif [ -d "$WORKDIR" ]; then
             SaveDaTa     # Save data does not save the package lists sessions unless the --keep option is chosen
                          # It only saves the dnf rpm cache and the files in the dracut,grub2, boot, data and extraconfig directories
                          # which may of may not have been modified by ther user
             RestoreDaTa  # RestoreDaTa also cleans and recreates the $WORKDIR

        fi
     fi   
 else
        # Expressly for debugging ABF=1 outside of the ABF builder
        if [ "$IN_ABF" = '1' ] && [ -n "$DEBUG" ] && [ "$WHO" != 'omv' ] && [ -n "$NOCLEAN" ]; then
            touch "$WORKDIR"/.new
            printf "%s\n" "Using noclean inside abf mode debug instance"
        else
            RemkWorkDir
        fi
 fi
 
	# Assign the config build list
	if [ "$TYPE" = 'my.add' ]; then
		FILELISTS="$WORKDIR/iso-pkg-lists-${TREE,,}/omdv-minimal.lst"
		printf "%s\n" " " "-> You are creating a user build" "This build will use the the omdv_minimal_iso.lst to create a basic iso"
			printf "%s\n" "A git repository with basic build lists will be created in directory named "$UHOME/$LREPODIR"." \
			"The directory is maintained as a git repository, this script will never overwrite it" \
            "Additional packages or files to be included on the iso may be added to the file my.add" \
			"Packages or files that you wish to be removed may be added to the file my.rmv" \
			"In addition you will need to provide the name of the executable for the Window Manager
			and the name you wish to assign to the desktop file associated with it"
		userISONme
		if [ "$UISONAME" == "$LREPODIR" ] && [ ! -d "$UHOME"/"$LREPODIR" ]; then
           mkeUsrListRepo
        else 
            printf "%s\n" "Your list repo name does not match your iso name this is not an error but an list repo will not be created." \
            "You will need to run a basic build with --lreposet set to your required directory." \
            "See the help for more information"
        fi
	elif [ "$TYPE" = 'plasma-wayland' ]; then
		FILELISTS="$WORKDIR/iso-pkg-lists-${TREE,,}/${DIST,,}-plasma.lst"
	else
		FILELISTS="$WORKDIR/iso-pkg-lists-${TREE,,}/${DIST,,}-${TYPE,,}.lst"
	fi

	# Create the EFI directory
	mkdir -m 0755 -p "$ISOROOTNAME"/EFI/BOOT
	# and the grub directory
	mkdir -m 0755 -p "$ISOROOTNAME"/boot/grub
	
mKeBuild_id() {
	printf "%s\n" "Create the BUILD_ID"
	if [ "$IN_ABF" = '0' ]; then
		if [ -f "$COMMITDIR"/sessrec/.build_id ]; then
			# The BUILD_ID has already been saved. Used to create commit messages.
			BUILD_ID=$(cat "$COMMITDIR"/sessrec/.build_id)
		else
			BUILD_ID=$(($RANDOM%9999+1000))
			echo ${BUILD_ID} > "$COMMITDIR"/sessrec/.build_id
		fi
	else
		BUILD_ID=$(($RANDOM%9999+1000))
	fi
}
# START ISO BUILD
	mkISOLabel
	mkeREPOdir #creates users personal repo
	mKeBuild_id	
	showInfo
	getPkgList  #gets the package lists from git hub from barnch set by --isover
	MkeListRepo # Create git repo for pkg lists
	DtctCmmt    # Check for changes and set change flag 
	InstallRepos
	updateSystem
	createChroot
	createInitrd
	createMemDisk
	createUEFI
	setupGrub2
	setupISOenv
	ClnShad
	InstallRepos
	createSquash
	buildIso
	postBuild
	FilterLogs
	#END
}


########################
#   Start functions    #
########################
# TODO:
# Test --auto-update switch
# Generally update/upgrade nneds lloking at
# Do we need a skip list?
# sort out the chnage flag
# note that it could be activated before the chroot is build so it needs to be qualified

hlpprtf() {
COLUMNS=`tput cols`
FINAL=$(( COLUMNS - 80 ))
OP=`printf "%b\n\t\t\t" "$1" | fmt -w "$FINAL"`
# echo "$OP"
printf "%s\n" "$OP"
}

optprtf() {
COLUMNS=`tput cols`
FINAL=$(( COLUMNS - 100 ))
OPT=`printf "%s" "$1"` 
OPT1=`printf "%b" "\t\t$2" | fmt -w  "$FINAL" -c `
printf "%s" "$OPT"; printf "%s\n" "${OPT1//$'\n'$'\t'/$'\n'$'\t'$'\t'}" 
}
bold=$(tput bold)
normal=$(tput sgr0)
ulon='\033[4m' # set underline on


usage_help() {
	if [ -z "$EXTARCH" ] && [ -z "$TREE" ] && [ -z "$VERSION" ] && [ -z "$RELEASE_ID" ] && [ -z "$TYPE" ] && [ -z "$DISPLAYMANAGER" ]; then
       printf "%b\n" ""
		printf "%b\t" "Please run script with arguments" "usage $0 [options]"
		printf "%b\n" "" "\t\t\t\t${ulon}${bold}GENERAL OPTIONS${normal}"
		
		optprtf "--arch=     " "Architecture of packages: i686, x86_64, znver1"
		optprtf "--tree=     " "Branch of software repository: cooker, lx4"
		optprtf "--version=" "Version for software repository: 4.0"
		optprtf "--release_id=" "Release identifer: alpha, beta, rc, final"
		optprtf "--type=     " "User environment type desired on ISO: plasma, mate, lxqt, icewm, xfce4, weston, gnome3, minimal, user. NOTE: When type is set to user an interactive session will be invoked where the user will be asked for the iso name and the command required to start the desired window manager. Both entries must be valid for a proper build of the new iso. No error check is performed on the values entered." 
		hlpprtf "\t\t\tBy default the system build a minimal iso from a list repo with the user selected name. Subsequently the user may add additional include lines, packages or local filenames directories for inclusionto the my.add file in their repository named in the first step. As a special feature the list repo can be created ahead of the build if the iso name is the same as the name passed to the --lrepodir option. If this is the case the script will exit after creating the list repo to allow the user to add packages or includes to the my.add file in the repo before building the iso."  
		printf "%b" "--displaymanager=" "\tDisplay Manager used in desktop environemt: sddm , none\n"
		optprtf "--workdir=" "Set directory where ISO will be build The default is ~/omdv-buildchroot-<arch>"
		optprtf "--outputdir=" "Set destination directory to where put final ISO file. The default is ~/omdv-buildchroot-<arch>/results"
		printf "%b" "--boot-kernel-type" "\tKernel to use for booting, if different from standard kernel. Grub's menu will offer alternate kernels for booting\n"
		optprtf "--auto-update" "Update the build chroot to the latest package versions. Saves rebuilding. Runs dnf --refresh distro-sync on the chroot"
		printf -vl "%${COLUMNS:-`tput cols 2>&-||echo 80`}s\n" && echo ${l// /-}
		printf "%b\n" "\t\t\t\t${ulon}${bold}REPOSITORY MANAGEMENT${normal}"
        hlpprtf "\t\t\tSeveral options allow the selection of additional repositories in addition to the default (main). Please note that is the following options are used the selected repositories will be left enabled on the iso. If you just want the default repositories on the iso use the --baserepo switch in addition to the other selectors."
        optprtf "--testrepo" "Enables the testing repo for the main repository" 
        optprtf "--unsupprepo" "Enables the unsupported repo" 
        optprtf "--repolist" "Allows a list of comma separated repoid's to enable.  i.e. --repolist=unsupported,updates,restricted To obtain a list of repo-ids run 'dnf --quiet repolist --all' in a terminal. There is also a list in the documentation"
        optprtf "--baserepo" "Resets the above options to the default for the repo group (rock, rolling, cooker)"
		printf -vl "%${COLUMNS:-`tput cols 2>&-||echo 80`}s\n" && echo ${l// /-}
		printf "%6b\n" "\t\t\t\t${ulon}${bold}USER BUILDS - REMASTERING${normal}"
		printf "%b\n"
		hlpprtf "\t\t\tProvision is made for custom builds in the form of two files in the package list directories. These are my.add and my.rmv you can add packages names to either of these files and they will be added or removed. You may also add full paths to local rpm files and these will be installed as well. Including other package lists is also supported see the package list files for the 'include' syntax. The my.rmv file can be used to temporarily remove packages from the package lists that are failing to install without the need to modify the original lists. The files are stored in a directory which is set up as a git repository; each time the script is run this directory is checked for changes and if any are found they committed to the git repository using a commmit message which contains the build-id and the number of times the script has been run thus providing a full record of the session. Note that changes to ALL the files are recorded and it is not mandatory that you use my.add or my.rmv it is just more convenient. my.rmv is the only way to remove packages from the chroot when using the --noclean and --rebuild options. To enable the user to create different custom builds and return to them easily the --lrepodir=<dirpath> option is provided. The dirpath defaults to ~/ISOROOT but may be pointed to any directory path on the system. The directory once created is never deleted by the script. It is for the user to remove redundant data directories. The script records the last used data directory and restores the content to the chroot unless --lrepodir is set to another value; then a new directory is created with files downloaded from the github repository corresponding to the repository you wish to build against.\n" 
        optprtf "--lrepodir=" "The lrepodir option sets the path to the storage directory for the package lists and other iso files. Once set the path for this directory will be remembered until the value of the lrepodir dir is changedl This initiates a fresh build with virgin files from the OMA repos."
		optprtf "--quicken" "Set up mksqaushfs to use no compression for faster iso builds. Intended mainly for testing"
		optprtf "--noclean" "Do not clean build chroot and keep cached rpms. Updates chroot with new packages. Option will not re-install the packages it will only retain them"
		printf "%b\n\n" "\t\t\tFor the following options you must have built an iso using the --noclean option before they can be applied"
		optprtf "--rebuild" "Recreates the build chroot and rebuilds from cached rpms and supplementary files. This allows a developer to modify the ""fixed"" iso setup files and preserve them from one run to the next"
		optprtf "--isover" "Allows the user to fetch a personal repository of build lists from their own repository. Currently the repository must reside on github as a branch of the omdv-build-iso repository"
		optprtf  "--usemirrors" "Use the mirrorlists to find packages; this option is only intended for use when the main ABF repositories are unavailable. It's possible that the iso will be built with out of date packages"
		printf -vl "%${COLUMNS:-`tput cols 2>&-||echo 80`}s\n" && echo ${l// /-}		
		printf "%6b\n" "\t\t\t\t${ulon}${bold}DEVELOPER OPTIONS${normal}"
		optprtf "--debug   " "Enable debug output basically enables set -x. This option also allows ABF=1 to be used loacally for testing"
		optprtf "--devmode" "Enables some developer aids see the README"
        optprtf "--parallel" "Runs each item in the build list as a single transaction. Used in conjunction with --maxerrors=<integer> (default=1) can be used when remastering isos to allow failures due to missing or broken packages. This feature is intended for debugging iso builds and is helpful in tracking down broken dependencies. A list of failed packages is produced at the end of the run after the iso is built."
		optprtf "--compressor" "This option allows a choice for the compressor to be used when the mksquashfs file is created. Valid choices are gzip, xz, lzo, lz4 and zstd." 
		optprtf "--keep  " "Retains only the build lists from one run to another. This means that if you modify the package lists within the working directory (usually omdv-build-chroot-<arch>) they will be restored unconditionally on the next run irrespective of any other flags. This can be used to create lists for new compilations. The build lists are stored in a git repository and each time there is a change a commit is performed thus keeping a record of the users session."
#		optprtf "--makelistrepo" "Just make a list repo if one does not already exist the --lrepodir, --arch and --tree options must be set. Optionally the --isover option may be set to direct the script to an alternative branch on GitHub. The script will create the repo and then exit" This feature is untested
		printf "%b\n" 
	
		printf "%b\n" "For example:"
		printf "%b\n" "omdv-build-iso.sh --arch=x86_64 --tree=cooker --version=4.0 --release_id=alpha --type=plasma --displaymanager=sddm"
		printf "%b\n" "Note that when --type is set to user the user may select their own ISO name during the execution of the script"
		printf "%b\n" "For detailed usage instructions consult the files in /usr/share/omdv-build-iso/docs/"
		printf "%b\n" "Exiting."
		exit 1
	else
		return 0
	fi
}

allowedOptions() {
	if [ "$ABF" = '1' ]; then
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
		if [ -n "$NOCLEAN" ] && [ -n "$REBUILD" ]; then
			printf "%s\n" "-> You cannot use --noclean and --rebuild together"
			exit 1
		fi
		if [ -n "$REBUILD" ]; then
			printf "%s\n" "-> You cannot use --rebuild inside ABF (https://abf.openmandriva.org)"
			exit 1
		fi
	else
		IN_ABF=0
	fi
	printf  "%s\n" "In abf = $IN_ABF"
}

setWorkdir() {
	# Set the $WORKDIR
	# If ABF=1 then $WORKDIR codes to /bin on a local system so if you try and test with ABF=1 /bin is rm -rf ed.
	# To avoid this and to allow testing use the --debug flag to indicate that the default ABF $WORKDIR path should not be used
	# To ensure that the WORKDIR does not get set to /usr/bin if the script is started we check the WORKDIR path used by abf and
	# To allow testing the default ABF WORKDIR is set to a different path if the DEBUG option is set and the user is non-root.
	if [ "$IN_ABF" = '0' ]; then
		if [ -z "$WORKDIR" ]; then
			WORKDIR="$UHOME/omdv-build-chroot-$EXTARCH"
			export WORKDIR
        fi
        # Make the directory for saving data between runs
        mkdir -p "${UHOME}"/ISOBUILD
		BUILDSAV="${UHOME}"/ISOBUILD 
    else
        if [ "$IN_ABF" = '1'  ] && [ -d '/home/omv/docker-iso-worker' ]; then
            # We really are in ABF
            echo "using realpath"
            WORKDIR=$(realpath "$(dirname "$0")")
        elif [ -n "$DEBUG" ]; then
            if [ -z "$WORKDIR" ]; then
                WORKDIR="$UHOME/omdv-build-chroot-$EXTARCH"
            fi
            printf "%s\n" "-> Debugging ABF build locally"
        else
            printf "%s\n" "-> DO NOT RUN THIS SCRIPT WITH ABF=1 ON A LOCAL SYSTEM WITHOUT SETTING THE DEBUG OPTION"
            exit 1
        fi
    fi
	printf "%s\n" "-> The work directory is $WORKDIR"
	# Define these earlier so that files can be moved easily for the various save options
	# this is where rpms are installed
	CHROOTNAME="$WORKDIR/BASE"
	# this is where ISO files are created
	ISOROOTNAME="$WORKDIR/ISO"
	mkdir -p ${CHROOTNAME}
	mkdir ${ISOROOTNAME}
}

RemkWorkDir() {
	echo "Remake dirs"
	rm -rf "$WORKDIR"
	mkdir -p ${WORKDIR}
	# Create the mount points
	mkdir -p "${CHROOTNAME}/proc ${CHROOTNAME}/sys ${CHROOTNAME}/dev ${CHROOTNAME}/dev/pts"
	# Create the ISO directory
	mkdir -p ${ISOROOTNAME}
	# Create the session record directorygetpkglist
#	mkdir -p ${LREPODIR}/sessrec
    #Call the function instead
#    mkeREPOdir
	touch ${WORKDIR}/.new
}

SaveDaTa() {
	printf "%s\n" "Saving config data"
#	if [ -n "$KEEP" ]; then
#		mv "$WORKDIR/iso-pkg-lists-${TREE,,}" "$BUILDSAV/iso-pkg-lists-${TREE,,}"
#		mv "$LREPODIR/sessrec" "$BUILDSAV/sessrec"
#	fi
    if [ -n "$KEEP" ] || [ -n "$REBUILD" ]; then
        printf "%s\n" "-> Saving system files for rebuild"
        mv "$WORKDIR/dracut" "$BUILDSAV/dracut"
        mv "$WORKDIR/grub2" "$BUILDSAV/grub2"
        mv "$WORKDIR/boot" "$BUILDSAV/boot"
        mv "$WORKDIR/data" "$BUILDSAV/data"
        mv "$WORKDIR/extraconfig" "$BUILDSAV/extraconfig"
        printf "%s\n" "-> Saving rpms for rebuild"
        mv "$CHROOTNAME/var/cache/dnf/" "$BUILDSAV/dnf"
        mv "$CHROOTNAME/etc/dnf/" "$BUILDSAV/etc/dnf"
	fi
}

RestoreDaTa() {
	printf "%s\n"  "->	Cleaning WORKDIR"
	# Re-creates the WORKDIR and populates it with saved data
	# In the case of a rebuild the $CHROOTNAME dir is recreated and the saved rpm cache is restored to it..
	rm -rf "$WORKDIR"
	mkdir -p "$WORKDIR"

	if [ -n "$KEEP" ] || [ -n "$REBUILD" ]; then
        printf "%s\n" "-> Restoring system files"
        mv "$BUILDSAV/dracut" "$WORKDIR/dracut"
        mv "$BUILDSAV/grub2" "$WORKDIR/grub2"
        mv "$BUILDSAV/boot" "$WORKDIR/boot"
        mv "$BUILDSAV/data" "$WORKDIR/data"
        mv "$BUILDSAV/extraconfig" "$WORKDIR/extraconfig"
	fi
	if [ -n "$REBUILD" ]; then
		printf "%s\n" "-> Restoring rpms for new build"
		#Remake needed directories
		mkdir -p "$CHROOTNAME/proc" "$CHROOTNAME/sys" "$CHROOTNAME/dev/pts"
		mkdir -p "$CHROOTNAME/var/lib/rpm" #For the rpmdb
		mkdir -p "$CHROOTNAME/var/cache/dnf"
		mv "$BUILDSAV/dnf" "$CHROOTNAME/var/cache/"
		mv "$BUILDSAV/etc/dnf" "$CHROOTNAME/etc/dnf/"
	else
		# Clean out the dnf dir
		cd "$BUILDSAV"||exit
		/bin/rm -r ./dnf
	fi
	touch "$WORKDIR/.new"
}

## (crazy) Fixme
umountAll() {
	printf "%s\n" "-> Unmounting all."
	unset KERNEL_ISO
	umount -l "$1"/proc 2> /dev/null || :
	umount -l "$1"/sys 2> /dev/null || :
	umount -l "$1"/dev/pts 2> /dev/null || :
	umount -l "$1"/dev 2> /dev/null || :
	umount -l "$1"/run/os-prober/dev/* 2> /dev/null || :
	umount -l "$IMGNME" 2> /dev/null || :
}

errorCatch() {
	printf "%s\n" "-> Something went wrong." "Exiting"
	FilterLogs
	unset KERNEL_ISO
	unset UEFI
	unset MIRRORLIST
	unset BOOT_KERNEL_ISO
	#Maybe need to clear the COMMITDIR with user interaction
	# (crazy) umountAll() ?
	umount -l /mnt
	losetup -D
#	if [ -z $DEBUG ] || [ -z $NOCLEAN ] || [ -z $REBUILD ]; then
		# for some reason the next line deletes irrespective of flags
		#	rm -rf $(dirname "$FILELISTS")
		umountAll "$CHROOTNAME"
		#	rm -rf "$CHROOTNAME"
#    else
		umountAll "$CHROOTNAME"
#	fi
	#if $1 is set - clean exit
	exit 1
}

# Don't leave potentially dangerous stuff if we had to error out...
trap errorCatch ERR SIGHUP SIGINT SIGTERM

userISONme() {
	printf "%s\n" "Please give a name to your iso e.g Enlight" "This will also be the name of the WM desktop file associated with it"
	read -r in1
	echo "$in1"
	if [ -n "$in1" ]; then
		printf "%s\n" "The isoname will be $in1" "Is this correct y or n ?"
		cfrmISONme
	fi
	printf "%s\n" "Your iso's name will be $UISONAME" " "
	
	printf "%s\n" "Please provide the name of the window manager executable you wish to use for your desktop session."
	read -r in1
	echo "$in1"
	if [ -n "$in1" ]; then
		printf "%s\n" "The WM executable will be $in1" "Is this correct y or n ?"
		cfrmWMNme
    fi
    printf "%s\n" "Your window manager executable is named WMNAME" " "
}

cfrmISONme() {
	read -r in2
	echo $in2
	if [ $in2 = 'yes' ] || [ $in2 = 'y' ]; then
		UISONAME="$in1"
		return 0
	fi
	if [ $in2 = 'no' ] || [ $in2 = 'n' ]; then
		userISONme
	fi
}

cfrmWMNme() {
	read -r in2
	echo $in2
	if [ $in2 = 'yes' ] || [ $in2 = 'y' ]; then
		WMNAME="$in1"
		return 0
	fi
	if [ $in2 = 'no' ] || [ $in2 = 'n' ]; then
		userISONme
	fi
}

mkISOLabel() {
	# Create the ISO directory
	mkdir -m 0755 -p "$ISOROOTNAME"/EFI/BOOT
	# and the grub diectory
	mkdir -m 0755 -p "$ISOROOTNAME"/boot/grub

	# UUID Generation. xorriso needs a string of 16 asci digits.
	# grub2 needs dashes to separate the fields..
	GRUB_UUID="$(date -u +%Y-%m-%d-%H-%M-%S-00)"
	ISO_DATE="$(printf "%s" "$GRUB_UUID" | sed -e s/-//g)"
	# in case when i386 is passed, fall back to i686
	[ "$EXTARCH" = 'i386' ] && EXTARCH=i686
	[ "$EXTARCH" = 'i586' ] && EXTARCH=i686

	if [ "${RELEASE_ID,,}" = 'final' ]; then
		PRODUCT_ID="OpenMandrivaLx.$VERSION"
	elif  [ "${RELEASE_ID,,}" = 'beta' ]; then
		RELEASE_ID="$RELEASE_ID.$(date +%Y%m%d).$BUILD_ID"
	elif [ "${RELEASE_ID,,}" = 'alpha' ]; then
		RELEASE_ID="$RELEASE_ID.$(date +%Y%m%d).$BUILD_ID"
	fi
	# Check if user build if true fixup name logic
	if [ "$TYPE" = 'my.add' ]; then
		PRODUCT_ID="OpenMandrivaLx.$VERSION-$RELEASE_ID-$UISONAME"
	else
		PRODUCT_ID="OpenMandrivaLx.$VERSION-$RELEASE_ID-$TYPE"
	fi
	printf "%s" "$PRODUCT_ID"

	LABEL="$PRODUCT_ID.$EXTARCH"
	[ $(echo "$LABEL" | wc -m) -gt 32 ] && LABEL="OpenMandrivaLx_$VERSION"
	[ $(echo "$LABEL" | wc -m) -gt 32 ] && LABEL="$(echo "$LABEL" |cut -b1-32)"
}

updateSystem() {
	# Remember it's the local system we are updating here not the chroot

	ARCH="$(rpm -E '%{_target_cpu}')"
	HOST_ARCHEXCLUDE=""
	[ -z "$ARCH" ] && ARCH="$(uname -m)"
	echo $ARCH |grep -qE "^arm" && ARCH=armv7hnl
	echo $ARCH |grep -qE "i.86" && ARCH=i686

	# Exclude 32-bit compat packages on multiarch capable systems
	case $ARCH in
	znver1|x86_64)
		HOST_ARCHEXCLUDE='--exclude=*.i686'
		;;
	aarch64)
		HOST_ARCHEXCLUDE='--exclude=*.armv7hnl'
		;;
	esac

	# List of packages that needs to be installed inside lxc-container and local machines
	RPM_LIST="xorriso squashfs-tools  bc imagemagick kpartx gdisk gptfdisk parallel git"
	if [ `rpm -q $RPM_LIST | wc -l`  == "`wc -w <<< ${RPM_LIST}`" ]; then
       printf "%s\n" "->All the correct system files are installed "
        if [ ! -d "$WORKDIR/dracut" ]; then
            find "$WORKDIR"
            touch "$WORKDIR/.new"
        else
            printf "%s\n" "-> Your build lists have been retained" # Files already copied
        fi
	else
        printf "%s\n" "-> Installing rpm files inside system environment"
        #--prefer /distro-theme-OpenMandriva-grub2/ --prefer /distro-release-OpenMandriva/ --auto
        dnf install -y --setopt=install_weak_deps=False --forcearch="${ARCH}" "${HOST_ARCHEXCLUDE}" ${RPM_LIST}
        echo "-> Updating rpms files inside system environment"
            if [ ! -d "$WORKDIR/dracut" ]; then
                find "$WORKDIR"
                touch "$WORKDIR/.new"
            else
                printf "%s\n" "-> Your build lists have been retained" # Files already copied
            fi
    fi
	# Make our directory writeable by current sudo user
	chown -R "$WHO":"$WHO" "$WORKDIR" #this doesn't do ISO OR BASE
}

getPkgList() {
    # Package list handling has two modes. When the script is run on ABF the package lists are obtained from the git repos.
    # The branch used will can be changed by using the --isover switch to get the lists from a different branch of the repo.
    # When operated outside of ABF it is assumed that the user will wish to modify the lists to create their own custom iso.
    # In this case the package lists are initially downloaded from GitHub and the versions that match the repo given on the command line
    # is copied to the directory pointed to by the LREPODIR variable. The LREPODIR variable is automatically set to a default if the user 
    # does not provide a name. The directory name is stored in an hidden file .rpodir in the users home directory.
    # A git repository is created in the LREPODIR and an an initial commit made with an automatically generated commit message which 
    # contains the "Build ID" and a session count which uniquely labels each commit. 
    # Should the user alter the files then on a subsequent iso build the files from the directory pointed to by the LREPODIR variable 
    # will be copied to the current working directory and a commit generated for the users changes. 
    # If the user wishes to create a new spin they can achieve this by setting the --lrepodir commandline option to a new directory 
    # where a new set of default files with their git repo will be created. Should the user wish to switch to their original iso using that directory name 
    # with the --lrepodir option will switch the default back to the original set of build lists. The number of directories is effectively unlimited.
    
        if [ ! -d "$WORKDIR/iso-pkg-lists-${TREE,,}" ]; then
            printf "%s\n" "-> Could not find $WORKDIR/iso-pkg-lists-${TREE,,}. Downloading from GitHub."
            # download iso packages lists from https://github.com
            # GitHub doesn't support git archive so we have to jump through hoops and get more file than we need
            if [ -n "$ISO_VER" ]; then
                export GIT_BRNCH="$ISO_VER"
            elif [ ${TREE,,} == "cooker" ]; then
                export GIT_BRNCH=master
            else
                export GIT_BRNCH=${TREE,,}
                # ISO_VER defaults to user build entry
            fi
                cd "$WORKDIR" ||  exit
        EX_PREF=./
        EXCLUDE_LIST="--exclude ${EX_PREF}.abf.yml --exclude ${EX_PREF}ChangeLog --exclude ${EX_PREF}Developer_Info --exclude ${EX_PREF}Makefile --exclude ${EX_PREF}README --exclude ${EX_PREF}TODO --exclude ${EX_PREF}omdv-build-iso.sh --exclude ${EX_PREF}omdv-build-iso.spec --exclude ${EX_PREF}docs/*  --exclude ${EX_PREF}tools/* --exclude ${EX_PREF}ancient/*"
                wget -qO- https://github.com/OpenMandrivaAssociation/omdv-build-iso/archive/"${GIT_BRNCH}".zip | bsdtar -xvf- ${EXCLUDE_LIST} --strip-components 1 
            if [ ! -e "$FILELISTS" ]; then
                printf "%s\n" "-> "$FILELISTS" does not exist. Exiting"
                errorCatch
            fi
            echo "THE CHROOT FILES ARE POPUKATED GHERE"
            if [ ! -f "$COMMITDIR"/"${FILELISTS#$WORKDIR/}" ]; then
                popREPOdir
            else
                printf "%s\n" "-> Copying users local package lists from "$LREPODIR" to workdir"
                cp -R ${COMMITDIR}/iso-pkg-lists-${TREE}/  ${WORKDIR}/
            fi
		fi
}

mkeREPOdir() {
#set -x
		if [  "$IN_ABF" = '0' ]; then 
            if [ -n "$LREPODIR" ]; then
                if [ "$LREPODIR" == "$(< "${UHOME}"/.rpodir)" ]; then 
                     COMMITDIR="$UHOME"/"$LREPODIR"
                else
                    printf "%s\n" "$LREPODIR" > "$UHOME"/.rpodir 
                    COMMITDIR="$UHOME"/"$LREPODIR"
                fi
            elif [ -f "$UHOME"/.rpodir ]; then
                LREPODIR="$(< "${UHOME}"/.rpodir)"
                
                #elif [ ! -d "$UHOME"/"$LREPODIR" ]; then
                #    mkdir -p "$UHOME"/"$LREPODIR"/sessrec              
                #elif [ -f "$UHOME"/.rpodir ]; then
                #    LREPODIR="$(< "${UHOME}"/.rpodir)"
               #     printf "%s\n" "$LREPODIR" > "$UHOME"/.rpodir
                    printf "%s\n" "$LREPODIR"
              #      mkdir -p "$UHOME/$LREPODIR"/sessrec
                    COMMITDIR="$UHOME"/"$LREPODIR"
            else
                LREPODIR="$WHO"s-user-iso
                mkdir -p "$UHOME"/"$LREPODIR"/sessrec
                echo "$LREPODIR" > "${UHOME}"/.rpodir
                COMMITDIR="$UHOME"/"$LREPODIR"
            fi
        else
            cd "$WORKDIR" || exit
            COMMITDIR="${WORKDIR}"
        fi
}
popREPOdir() {
        cp -r ${WORKDIR}/iso-pkg-lists-${TREE}/ "${COMMITDIR}"
        if  [ ! -f ${COMMITDIR}/iso-pkg-lists-${TREE}/my.add ]; then
            printf "%s\n" "There's been an error"
            printf "%s\n" "Please check whether the directory named in the hidden file .rpodir in your home directory \
            still exists and if it does it may still have the .git directory which will allow you to recover your package lists. \
            If no files exist please delete the .rpodir file and the directory named in it and start with a fresh build"
            errorCatch
        fi
}

showInfo() {
	echo $'###\n'
	printf "%s\n" "Building ISO with arguments:"
	printf "%s\n" "Distribution is $DIST"
	printf "%s\n" "Architecture for ISO is $EXTARCH"
	printf "%s\n" "Tree is $TREE"
	printf "%s\n" "Version is $VERSION"
	printf "%s\n" "Release ID is $RELEASE_ID"
	if [ "${TYPE,,}" = 'my.add' ]; then
		printf "%s\n" "TYPE is user"
	else
		printf "%s\n" "Type is $TYPE"
	fi
	if [ "${TYPE,,}" = 'minimal' ]; then
		printf "%s\n" "-> No display manager for minimal ISO."
	elif [ "${TYPE,,}" = "my.add" ] && [ -z "$DISPLAYMANAGER" ]; then
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

# Create git repo for the package lists so we can record user mode changes. 
MkeListRepo() {
	if [ ! -d "${COMMITDIR}/iso-pkg-lists-${TREE}/.git" ]; then
		printf "%s\n" "-> Creating package list repo"
		cd ${COMMITDIR}/iso-pkg-lists-${TREE}
		git init
		git add .
		git config user.email "omdv@abf.openmandriva.org"
		git config user.name "iso buider"
		MkeCmmtMsg
		git commit -a -m "$CMMTMSG"
	fi
}

# Detect whether the lists have changed and if so set the change flag, generate commit msg and commit the changes.
DtctCmmt() {
    if [ -d $COMMITDIR/iso-pkg-lists-$TREE ]; then
    cd ${COMMITDIR}/iso-pkg-lists-${TREE} || exit
	CHNGFLG=$(git diff)
        if [ -n "$CHNGFLG" ]; then
            MkeCmmtMsg
            git commit -a -m "$CMMTMSG"
        fi
	fi
}

# Create a sequential commit message
MkeCmmtMsg() {
    if [ ! -d ${COMMITDIR}/sessrec ]; then
    mkdir ${COMMITDIR}/sessrec
    else
        if  [ -f ${COMMITDIR}/sessrec/.seqnum ]; then
            SEQNUM=`cat ${COMMITDIR}/sessrec/.seqnum`
            SEQNUM=$((SEQNUM+1))
        else
            SEQNUM=1
        fi
	echo "$SEQNUM" >"${COMMITDIR}/sessrec/.seqnum"
	SESSNO=$(cat ${COMMITDIR}/sessrec/.build_id)
	CMMTMSG=$(printf "%s/n" "Changes for Build Id ${BUILD_ID}; Session No ${SEQNUM}")
	fi
}



## (crazy) move to arry's for the .lst stuff that is...
# Usage: getIncFiles [filename] xyz.* $"[name of variable to return]
# Returns a sorted list of include files
# Function: Gets all the include lines for the specified package file
# The full path to the package list must be supplied

getIncFiles() {
	# Define some local variables
	local __infile="$1"   # The main build file
	local __incflist="$2" # Carries returned variable
	local __addrpminc # It's critical that this is local otherwise the content of previous runs corrupts the current list.
	getEntrys() {
	local 9oi9__addrpminc # It's critical that this is local otherwise the content of previous runs corrupts the current list.
		# Recursively fetch included files
		while read -r r; do
			[ -z "$r" ] && continue
			# $'\n' nothing else works just don't go there.
			__addrpminc+=$'\n'"$WORKDIR/iso-pkg-lists-$TREE/$r"
			getEntrys "$WORKDIR/iso-pkg-lists-$TREE/$r"
			# Avoid sub-shells make sure commented out includes are removed.
		done < <(cat "$1" | grep '^[A-Za-z0-9 \t]*%include' | awk -F\./// '{print $2}' |  sed '/ #/d ; /^\s$/d ; /^$/d') > /dev/null 2>&1
		# The above may appear as a useless use of cat but it's removal results in a permission denied error (even as sudo)
		# Though the function still works fine. A bug for another day
	#	eval $__addrpminco="'$__addrpminc'"
	}
	getEntrys "$1"
	# Add the primary file to the list
   	__addrpminc+=$'\n'"$__infile"
	# Sort and remove dupes.
   	__addrpminc=$(printf "%s" "$__addrpminc" | sort -u | uniq -u)
   	# Export
	eval $__incflist="'$__addrpminc'"
	> /dev/null
}

# Usage: createPkgList  "$VAR" VARNAME
# Function: Creates lists of packages from package lists
# VAR: A variable containing a list of package lists
# VARNAME: A variable name to identify the returned list of packages.
# Intent: Can be used to generate named variables
# containing packages to install or remove.

# NOTE: This routine requires 'lastpipe' so that
# subshells do not dump their data.
# This requires that job control be disabled.

# real really FIXME! - crazy -
createPkgList() {
	set +m
	shopt -s lastpipe
	# Define a local variable to hold user VAR
	local __pkglist=$2 # Carries returned variable name
	# other locals not needed outside routine
	local __pkgs # The list of packages
	local __pkglst # The current package list
	while read -r __pkglst; do
		__pkgs+=$'\n'$(cat "$__pkglst") >/dev/null 2>1 
	done < <(printf '%s\n' "$1") >/dev/null 2>&1
	# sanitise regex compliments of TPG
	__pkgs=$(printf '%s\n' "$__pkgs" | grep -v '%include' | sed -e 's,		, ,g;s,  *, ,g;s,^ ,,;s, $,,;s,#.*,,' | sed -n '/^$/!p' | sed 's/ $//')
	# The above was getting comments that occured after the package name i.e. vim-minimal #mini-iso9660. but was leaving a trailing space which confused parallel and it failed the install

	eval $__pkglist="'$__pkgs'"
	if [ -n "$DEBUG" ]; then
		printf  "%s\n" "-> This is the $2 package list"
		printf "%s\n" "$__pkgs"
		printf "%s" "$__pkgs" >"$WORKDIR/$2.list"
	fi

	shopt -u lastpipe
	set -m
	> /dev/null
}

# Usage: mkOmSpin [main install file path} i.e. [path]/omdv-kde4.lst.
# Returns a variable "$INSTALL_LIST" containing all rpms
# to be installed
mkOmSpin() {
	getIncFiles "$FILELISTS" ADDRPMINC
	printf "%s" "$ADDRPMINC" > "$WORKDIR/inclist"
	printf "%s\n" "-> Creating OpenMandriva spin from" "$FILELISTS" " " "   Which includes"
	printf "%s" "$ADDRPMINC" | grep -v "$FILELISTS"
	createPkgList "$ADDRPMINC" INSTALL_LIST
	if [ -n "$DEVMODE" ]; then
		printf '%s' "$INSTALL_LIST" >"$WORKDIR/rpmlist" > /dev/null 2>&1
	fi
	mkUpdateChroot "$INSTALL_LIST"
}

# updateUserSpin [main install file path] i.e. path/omdv-kde4.lst
# Sets two variables
# INSTALL_LIST = All list files to be installed
# REMOVE_LIST = All list files to be removed
# This function only updates using the user my.add and my.rmv files.
# It is used to add user updates after the main chroot
# has been created with mkUserSpin.
updateUserSpin() {
if [ -n "$DEBUG" ]; then
echo "updateUserSpin"
fi
	printf "%s\n" "-> Updating user spin"
	getIncFiles "$WORKDIR/iso-pkg-lists-$TREE/my.add" UADDRPMINC
	# re-assign just for consistancy
	ALLRPMINC="$UADDRPMINC"
	getIncFiles "$WORKDIR/iso-pkg-lists-$TREE/my.rmv" RMRPMINC
    printf "%s\n" " " "-> This is the user include list"
	printf "%s\n" "$ALLRPMINC" "-> End of user include list" " "
	printf "%s\n" " " "-> This is the remove include list"
	printf "%s\n" "$RMRPMINC" "-> End of remove list" " "
	printf "%s\n" -> "Remove any duplicate includes"
	# This should signal an error to the user
	RMRPMINC_TMP=$(comm -12 <(printf '%s\n' "$ALLRPMINC" | sort ) <(printf '%s\n' "$RMRPMINC" | sort))
	if [ -n RMRPMINC_TMP ]; then
	printf "%s\n" -> "Error: ->> The are identical include files in the add and remove lists" "->> You probably don't want this"
	fi
	printf "%s\n" "-> Creating the package lists"
	createPkgList "$ALLRPMINC" INSTALL_LIST
	createPkgList "$RMRPMINC" REMOVE_LIST
	if [ -n "$DEVMODE" ]; then
		printf '%s\n' "$ALLRPMINC" >"$WORKDIR/add_incfile.list" " "
		printf '%s\n' "$RMRPMINC" >"$WORKDIR/remove_incfile.list" " "
	fi
	# Remove any packages that occur in both lists
	INSTALL_LIST=$(comm -13 <(printf '%s\n' "$REMOVE_LIST" | sort -u) <(printf '%s\n' "$INSTALL_LIST" | sort -u)) > /dev/null 2>&1
    printf "%s\n" "-> This is the install package list" "$INSTALL_LIST" "->End of install pkg list" " "
	printf "%s\n" "-> This is the remove package list" "$REMOVE_LIST" "End of remove pkg list"
	if [ -n "$DEVMODE" ]; then
		printf '%s\n\t' "$INSTALL_LIST" >"$WORKDIR/user_update_add_rpmlist" " "
		printf '%s\n\t' "$REMOVE_LIST" >"$WORKDIR/user_update_rm_rpmlist" " "
	fi
	# We don't want parallel here
	unset PLLL
	mkUpdateChroot "$INSTALL_LIST" "$REMOVE_LIST"
}

# mkUserSpin [main install file path} i.e. [path]/omdv-kde4.lst
# Sets two variables
# $INSTALL_LIST = All list files to be installed
# $REMOVE_LIST = All list files to be removed
# This function includes all the user adds and removes.
mkUserSpin() {
if [ -n "$DEBUG" ]; then
echo "mkUserSpin"
fi
	printf "%s\n" "-> Making a user spin"
	printf "%s\n" "Change Flag = $CHGFLAG"
	getIncFiles "$FILELISTS" ADDRPMINC
	getIncFiles "$WORKDIR/iso-pkg-lists-$TREE/my.add" UADDRPMINC
    # Combine the main and the users files"
	ALLRPMINC=$(echo "$ADDRPMINC"$'\n'"$UADDRPMINC" | sort -u)
	# Now for the remove list
	getIncFiles "$WORKDIR/iso-pkg-lists-$TREE/my.rmv" RMRPMINC
	printf "%s\n" "-> Removing the common include lines for the remove package includes"

	#Give some information
	printf "%s\n" "-> Creating $WHO's OpenMandriva spin from $FILELISTS" "  Which includes " "$ALLRPMINC"
	printf "%s\n" "-> Removing from $WHO's OpenMandriva spin from $FILELISTS" "  Which removes " "$RMRPMINC"
	if [ -n "$DEVMODE" ]; then
	printf "%s\n" "$ALLRPMINC" > "$WORKDIR/primary.list"
	printf "%s\n" "$ADDRPMINC" > "$WORKDIR/prime.list"
	printf "%s\n" "$RMRPMINC" | grep -v "$FILELISTS"
	printf "%s\n" "$RMRPMINC" > "$WORKDIR/rmprime.list"
	fi
	# Create the package lists
	createPkgList "$ALLRPMINC" INSTALL_LIST
	createPkgList "$RMRPMINC" REMOVE_LIST
    INSTALL_LIST=$(comm -13 <(printf '%s\n' "$REMOVE_LIST" | sort -u) <(printf '%s\n' "$INSTALL_LIST" | sort -u))
	if [ -n "$DEVMODE" ]; then
		printf '%s\n' "$INSTALL_LIST" >"$WORKDIR/user_add_rpmlist"
		printf '%s\n' "$REMOVE_LIST" >"$WORKDIR/user_rm_rpmlist"
	fi
	# Remove any files from the install list which in the remove list
	echo "This is the install list" " " "$INSTALL_LIST" " " "End of install list"
	mkUpdateChroot "$INSTALL_LIST" "$REMOVE_LIST"
}

# The MyAdd and MyRmv functions can't take full advantage of parallel until a full rpm dep list is produced
# which means using a solvedb setup. We can however make use of it's fail utility.. Add some logging too.

# Usage: MyAdd
MyAdd() {
if [ -n "$DEBUG" ]; then
echo "MyAdd"
fi
	if [ -n "$__install_list" ]; then
		printf "%s\n" "-> Installing user package selection" " "
		if [ -n "$PLLL" ]; then
            printf "%s\n" "$__install_list" | parallel --keep-order --joblog "$WORKDIR/install.log" --tty --halt now,fail="$MAXERRORS" -P 1 /usr/bin/dnf install -y --refresh --forcearch=${EXTARCH} ${ARCHEXCLUDE} --setopt=install_weak_deps=False --installroot "$CHROOTNAME" >"$WORKDIR/dnfopt.log" 
            #| tee "$WORKDIR/dnfopt.log"
        else
            /usr/bin/dnf install -y --refresh --forcearch="${EXTARCH}" ${ARCHEXCLUDE} --installroot "$CHROOTNAME" ${__install_list} | tee "$WORKDIR/dnfopt.log"
            >"$WORKDIR/dnfopt.log"
            #| tee "$WORKDIR/dnfopt.log"
            printf "%s\n" "$__install_list" >"$WORKDIR/RPMLIST.txt"
        fi
    fi
}

# Usage: MyRmv
MyRmv() {
if [ -n "$DEBUG" ]; then
echo "MyRmv"
fi
	if [ -n "$__remove_list" ]; then
        # Before we do anything here we have to consider that the user may have 
        # added packages to the remove list which have been breaking the build. 
        # What needs to be done is to remove any duplicates that appear in both lists.
        # Any common packages must be removed from BOTH lists
        # This needs to be done somewhere else
        # Also removing stuff that isn't yet installed also needs to be dealt with
        # 
		printf "%s" "-> Removing user specified rpms and orphans" " "
		/usr/bin/dnf autoremove -y  --installroot "$CHROOTNAME" "$__remove_list"
	else
		printf "%s\n" " " "-> No rpms need to be removed"
	fi
}

# Usage: mkUpdateChroot [Install variable] [remove variable]
# Function:	  If the --noclean option is set and a full chroot has been built
#			   (presence of .noclean in the chroot directory) then this function will be
#			   called when a change is detected in the users iso-build-lists.
#			   If the rebuild flag is set the entire chroot will be rebuilt using
#			   the main and user created configurations lists.
#			   It will first add any specified packages to the current chroot
#			   and then remove the specified packages using the auto-orphan option
#			   if the variable is not empty.
#			   As a minimum the INSTALL_LIST must exist in the environment.
#			   The optional REMOVE_LIST  can also be supplied.
#			   These variables must contain lists of newline
#			   separated package names for installation or removal.
#			   The variable names are flexible but their content and order on the commandline
#			   are mandatory.
mkUpdateChroot() {
	printf "%s\n\n" "-> Updating chroot"
#	echo "$1"
	 __install_list="$1"
	 __remove_list="$2"

	if [ "$IN_ABF" = '0' ]; then
		# Sometimes the order of add and remove are critical for example if a package needs to be replaced with the same package
		# the package needs to be removed first thus the remove list needs to be run first. If the same package exists in both
		# add and remove lists then remove list needs to be run first but there no point in running a remove list first if there's no rpms to remove because
		# they haven't been installed yet. So removing rpms only needs to be invoked first if the NOCLEAN flag is set indicating a built chroot. The problem
		# is that the replacepkgs flag does not install if the package has not been installed that are already there so the package has to be removed first
		# otherwise parts of the install list will fail. A replace list could be provided. A simple fix for the moment turn both operations into functions
		# and call then through logic which determines whether --noclean has been invoked. 
		if [ -n "$NOCLEAN" ] && [ -f "$CHROOTNAME/.noclean" ]; then
			MyRmv
			MyAdd
		else
			MyAdd
			MyRmv
		fi
	elif [ "$IN_ABF" = '1' ]; then
		printf "%s\n" "-> Installing packages at ABF" " "
		if [ -n "$__install_list" ]; then # Dont do it with an empty list
			if [ -n "$PLLL" ]; then
				printf "%s\n" "$__install_list" | parallel --keep-order --joblog "$WORKDIR/install.log" --tty --halt now,fail="$MAXERRORS" -P 1 /usr/bin/dnf install -y --refresh --forcearch=${EXTARCH} ${ARCHEXCLUDE} --setopt=install_weak_deps=False --installroot "$CHROOTNAME"  | tee "$WORKDIR/dnfopt.log"
			else
                /usr/bin/dnf install -y --refresh --forcearch="${EXTARCH}" ${ARCHEXCLUDE} --installroot "$CHROOTNAME" ${__install_list} | tee "$WORKDIR/dnfopt.log"
                printf "%s\n" "$__install_list" >"$WORKDIR/RPMLIST.txt"
			fi
		fi
	fi
}

FilterLogs() {
	printf "%s\n" "-> Make some helpful logs"
	if [ -f "$WORKDIR/install.log" ]; then
		# Create the header
		printf "%s\n" "" "" "RPM Install Success" " " >"$WORKDIR/rpm-install.log"
		head -1 "$WORKDIR/install.log" | awk '{print$1"\t"$3"\t"$4"\t"$7"\t\t"$10}' >>"$WORKDIR/rpm-install.log" #1>&2 >/dev/null
		printf "%s\n" "" "" "RPM Install Failures" " " >"$WORKDIR/rpm-fail.log"
		head -1 "$WORKDIR/install.log" | awk '{print$1"\t"$3"\t"$4"\t"$7"\t\t"$10}' >>"$WORKDIR/rpm-fail.log"

		# Append the data
		cat "$WORKDIR/install.log" | awk '$7  ~ /1/  {print$1"\t"$3"\t"$4"\t\t"$7"\t"$18}'>> "$WORKDIR/rpm-fail.log"
		cat "$WORKDIR/install.log" | awk '$7  ~ /0/  {print$1"\t"$3"\t"$4"\t\t"$7"\t"$18}' >> "$WORKDIR/rpm-install.log"
	fi
	# Make a dependency failure log
	if [ -f "$WORKDIR/dnfopt.log" ]; then
		grep -hr -A1 '\[FAILED\]' "$WORKDIR/dnfopt.log" | sort -u > "$WORKDIR/depfail.log"
		MISSING=`grep -hr -A1 'No match for argument' "$WORKDIR/dnfopt.log"`: 
		#if [ -n "$MISSING" ]; then
		#echo "$MISSING" "ERROR! Is your repo enabled"
		#fi
	fi
	if [ "$IN_ABF" = '1' ] && [ -f "$WORKDIR/install.log" ]; then
		cat "$WORKDIR/rpm-fail.log"
		printf "%s\n" " " "-> DEPENDENCY FAILURES"
		cat "$WORKDIR/depfail.log"
		cat "$WORKDIR/rpm-install.log" 
	fi
	# List the available repos and their status
	dnf repolist -C --installroot "$CHROOTNAME" --quiet  --all > REPO_STATUS.txt
	#Clean-up
	# rm -f "$WORKDIR/install.log"
}

InstallRepos() {
	# There are now different rpms available for cooker and release so these can be used to directly install the the repo files. The original function is kept just
	# in case we need to revert to git again for the repo files.
	#Get the repo files
	if [ -e "$WORKDIR"/.new ]; then
        PKGS=http://abf-downloads.openmandriva.org/"$TREE"/repository/$EXTARCH/main/release/
        cd "$WORKDIR"
        curl -s -L $PKGS |grep '^<a' |cut -d'"' -f2 >PACKAGES
        PACKAGES="openmandriva-repos openmandriva-repos-keys openmandriva-repos-pkgprefs dnf-conf"
        for i in $PACKAGES; do
            P=$(grep "^$i-[0-9].*" PACKAGES |tail -n1)
            if [ "$?" != '0' ]; then
                printf "%s\n" "Can't find $TREE version of $i, please report"
                exit 1
            fi
            wget $PKGS/$P
        done
    fi

	if [ -e "$WORKDIR"/.new ]; then
		rpm -Uvh --root "$CHROOTNAME" --force --oldpackage --nodeps *.rpm
	else
		/bin/rm -rf "$CHROOTNAME"/etc/yum.repos.d/*.repo "$CHROOTNAME"/etc/dnf/dnf.conf
		rpm --reinstall -vh --root "$CHROOTNAME" --replacefiles --nodeps  *.rpm
	fi

	if [ -e "$CHROOTNAME/etc/yum.repos.d" ]; then ## we may hit ! -e that .new thing
		ls -l $CHROOTNAME/etc/yum.repos.d
	else
		printf "%s\n"  "/etc/yum.repos.d not present"
	fi

	# Use the master repository, not mirrors
	if [ -e "$WORKDIR"/.new ]; then
        if [ -n "$USEMIRRORS" ]; then
            printf "->WARNING<- YOU HAVE ELECTED TO DOWNLOAD THE PACKAGES FOR THIS BUILD FROM A MIRROR. PACKAGE VERSIONS MAY NOT BE UP TO DATE"
        else
        sed -i -e 's,^mirrorlist=,#mirrorlist=,g;s,^# baseurl=,baseurl=,g' $CHROOTNAME/etc/yum.repos.d/*.repo
        fi
	# we must make sure that the rpmcache is retained
	echo "keepcache=1" >> $CHROOTNAME/etc/dnf/dnf.conf
    # This setting will be overwritten when the repos are re-installed at the end; however
    # because the repo rpms are installed with rpm -Uvh the cache wont be cleared as dnf won't be run so the vache must be removed.
    fi

	#Check the repofiles and gpg keys exist in chroot
	if [ ! -s "$CHROOTNAME/etc/yum.repos.d/openmandriva-cooker-${EXTARCH}.repo" ] || [ ! -s "$CHROOTNAME/etc/pki/rpm-gpg/RPM-GPG-KEY-OpenMandriva" ]; then
		printf "%s\n"  "Repo dir bad install."
		errorCatch
	else
		printf "%s\n" "Repository and GPG files installed sucessfully."
		/bin/rm -rf $CHROOTNAME/etc/yum.repos.d/*.rpmnew
	fi
	# First make sure cooker is disabled
	dnf --installroot="$CHROOTNAME" config-manager --disable cooker-"$EXTARCH"
	# Then enable the main repo of the chosen tree
	dnf --installroot="$CHROOTNAME" config-manager --enable "$TREE"-"$EXTARCH"
	# Clean up
	if [ ! -e "$WORKDIR"/.new ]; then
		/bin/rm -rf "$WORKDIR"/*.rpm
	fi
	# This must only happen on the second invocatiom.
	if [ -n "$BASEREPO" ]; then
        printf "%s\n" "->Enabling the main repo only"
    else
        if [ -n "$UNSUPPREPO" ]; then
            dnf --installroot="$CHROOTNAME" config-manager --enable "$TREE"-"$EXTARCH"-unsupported
        fi
        # Some pre-processing required here because of the structure of repoid's
        if [ -n "$ENABLEREPO" ]; then
                ENABLEREPO=`tr "," " " <<< $ENABLEREPO`
            #for rpo in ${ENABLEREPO//,/]; do
            dnf --installroot="$CHROOTNAME" config-manager --releasever=${TREE} --enable ${ENABLEREPO}
            #done
        fi
        if [ -n "$TESTREPO" ]; then
            dnf --installroot="$CHROOTNAME" config-manager --enable "$TREE"-testing-"$EXTARCH"
        fi
    fi
		# DO NOT EVER enable non-free repos for firmware again , but move that firmware over if *needed*
}

# Usage: createChroot packages.lst /target/dir
# Creates a chroot environment with all packages in the packages.lst
# file and their dependencies in /target/dir

	# Start rpm packages installation
	# CHGFLAG=1 Indicates a global change in the iso lists

	# If we are IN_ABF=1 then build a standard iso
	# If we are IN_ABF=1 and DEBUG is set then we are running the ABF mode locally.
	# In this mode the NOCLEAN flag is allowed.
	# If set this will build a standard iso initially once built subsequent runs
	# with NOCLEAN set will update the chroot with any changed file entries.
    # If we are IN_ABF=0 then
	# If the NOCLEAN flag and the .noclean file does not exist and there is no /lib/modules in the chroot 
	#then an iso will be built using the standard files
	# plus the contents of the two user files my.add and my.rmv.
	
	# Once built subsequent runs with NOCLEAN set will update the chroot with
	# any changed entries in the user files only.
	# if --rebuild is set then rebuild the chroot using the standard and user file lists.
	# This uses the preserved rpm cache to speed up the rebuild.
	# Files that were added to the user files will be downloaded.
	
createChroot() {
# The CHGFLAG section needs fixing or removing
#	if [ -n "$CHGFLAG" ]; then
#		if [[ ( -f "$CHROOTNAME"/.noclean && -d "$CHROOTNAME/lib/modules") || -n "$REBUILD" ]]; then
#			printf "%s\n" "-> Updating existing chroot $CHROOTNAME"
#			#what will we call here
#		else
#			printf "%s\n" "-> Creating chroot $CHROOTNAME"
#		fi
		# Make sure /proc, /sys and friends can be mounted so %post scripts can use them
		mkdir -p "$CHROOTNAME/proc" "$CHROOTNAME/sys" "$CHROOTNAME/dev" "$CHROOTNAME/dev/pts"

		if [ -n "$REBUILD" ]; then
			ANYRPMS=$(find "$CHROOTNAME/var/cache/dnf/" -name "basesystem-minimal*.rpm"  -type f  -printf %f)
			if [ -z "$ANYRPMS" ]; then
				printf "%s\n" "-> You must run with --noclean before you use --rebuild"
				errorCatch
			fi
		else
			printf "%s\n" "-> Rebuilding."
		fi
#	fi

	mount --bind /proc "$CHROOTNAME"/proc
	mount --bind /sys "$CHROOTNAME"/sys
	mount --bind /dev "$CHROOTNAME"/dev
	mount --bind /dev/pts "$CHROOTNAME"/dev/pts


        if [ "$IN_ABF" = '1' ]; then
            # Just build a chroot if DEBUG is not we will have 
            # been thrown out long before we have got here.
            printf "%s\n" "Creating chroot"
            mkOmSpin
        elif [ ! -f "$CHROOTNAME/.noclean" ]; then
            printf "%s\n" "Creating an user chroot"
            mkUserSpin
            touch "$CHROOTNAME/.noclean"
        fi

        if [ "$IN_ABF" = '0' ]; then
            if [ -n "$REBUILD" ]; then
                printf  "%s\n" "-> Rebuilding."
                mkUserSpin "$FILELISTS"
            elif [ -n "$AUTO_UPDATE" ]; then
                /usr/bin/dnf --refresh distro-sync --installroot "$CHROOTNAME"
            elif [ -n "$NOCLEAN" ] && [ -f "$CHROOTNAME"/.noclean ]; then
                printf "%s\n" "-> Updating user spin"
                updateUserSpin
            else 
                mkUserSpin 
            fi
        fi

        
        printf "%s\n" "I am here"
        
        # Did it return 0k
        if [ $? != 0 ] && [ ${TREE,,} != "cooker" ]; then
            printf "%s\n" "-> Can not install packages from $FILELISTS"
            errorCatch
        fi
        
        # Check CHROOT
        if [ ! -d  "$CHROOTNAME"/lib/modules ]; then
            printf "%s\n" "-> Broken chroot installation." "Exiting"
            /bin/rm -f $CHROOTNAME/.noclean
            errorCatch
	fi



# There's a problem here if you have something like desktop and desktop-clang kernels as module detection fails if 
# the boot kernel type is defined as desktop. You have to be careful about what you put in --boot-kernel-type
# Somehow this has to be fixed perhaps with a lookup or translation table.
set -x	# Export installed and boot kernel
	pushd "$CHROOTNAME"/lib/modules > /dev/null 2>&1
	BOOT_KERNEL_ISO="$(ls -d --sort=time [0-9]* | grep "$BOOT_KERNEL_TYPE" | head -n1 | sed -e 's,/$,,')"
	export BOOT_KERNEL_ISO
	if [ -n "$BOOT_KERNEL_TYPE" ]; then
		echo "$BOOT_KERNEL_TYPE" > "$CHROOTNAME/boot_kernel"
		KERNEL_ISO=$(ls -d --sort=time [0-9]* | grep -v "$BOOT_KERNEL_TYPE" | head -n1 | sed -e 's,/$,,')
	else
		KERNEL_ISO=$(ls -d --sort=time [0-9]* |head -n1 | sed -e 's,/$,,')
	fi
	export KERNEL_ISO
	popd > /dev/null 2>&1
set +x	# remove rpm db files which may not match the target chroot environment
	chroot "$CHROOTNAME" rm -f /var/lib/rpm/__db.*
}

createInitrd() {

	# Check if dracut is installed
	if [ ! -f "$CHROOTNAME/usr/sbin/dracut" ]; then
		printf "%s\n" "-> dracut is not installed inside chroot." "Exiting."
		errorCatch
	fi

	# Build initrd for syslinux
	printf "%s\n" "-> Building liveinitrd-${BOOT_KERNEL_ISO} for ISO boot"
	if [ ! -f "$WORKDIR/dracut/dracut.conf.d/60-dracut-isobuild.conf" ]; then
		printf "%s\n" "-> Missing $WORKDIR/dracut/dracut.conf.d/60-dracut-isobuild.conf." "Exiting."
		errorCatch
	fi

	cp -f "$WORKDIR"/dracut/dracut.conf.d/60-dracut-isobuild.conf "$CHROOTNAME"/etc/dracut.conf.d/60-dracut-isobuild.conf
	
	if [ ! -d "$CHROOTNAME"/usr/lib/dracut/modules.d/90liveiso ]; then
		printf "%s\n" "-> Dracut is missing 90liveiso module. Installing it."

		if [ ! -d "$WORKDIR"/dracut/90liveiso ]; then
			printf "%s\n" "-> Cant find 90liveiso dracut module in $WORKDIR/dracut. Exiting." " "
			errorCatch
		fi

		cp -a -f "$WORKDIR"/dracut/90liveiso "$CHROOTNAME"/usr/lib/dracut/modules.d/
		chmod 0755 "$CHROOTNAME"/usr/lib/dracut/modules.d/90liveiso
		chmod 0755 "$CHROOTNAME"/usr/lib/dracut/modules.d/90liveiso/*.sh
	fi

	# Fugly hack to get /dev/disk/by-label
	sed -i -e '/KERNEL!="sr\*\", IMPORT{builtin}="blkid"/s/sr/none/g' -e '/TEST=="whole_disk", GOTO="persistent_storage_end"/s/TEST/# TEST/g' "$CHROOTNAME"/lib/udev/rules.d/60-persistent-storage.rules
	if [ $? != 0 ]; then
		printf "%s\n" "-> Failed with editing /lib/udev/rules.d/60-persistent-storage.rules file. Exiting."
		errorCatch
	fi

	if [ -f "$CHROOTNAME"/boot/liveinitrd.img ]; then
		rm -rf "$CHROOTNAME"/boot/liveinitrd.img
	fi

	# Set default plymouth theme
	if [ -x "$CHROOTNAME"/usr/sbin/plymouth-set-default-theme ]; then
		chroot "$CHROOTNAME" /usr/sbin/plymouth-set-default-theme OpenMandriva
	fi

	# Building liveinitrd
	chroot "$CHROOTNAME" /usr/sbin/dracut -N -f --no-early-microcode --nofscks /boot/liveinitrd.img --conf /etc/dracut.conf.d/60-dracut-isobuild.conf "$BOOT_KERNEL_ISO"
    if [ -n "$BOOT_KERNEL_TYPE" ]; then
        chroot "$CHROOTNAME" /usr/sbin/dracut -N -f --no-early-microcode --nofscks /boot/liveinitrd1.img --conf /etc/dracut.conf.d/60-dracut-isobuild.conf "$KERNEL_ISO"
    fi
	if [ ! -f "$CHROOTNAME"/boot/liveinitrd.img ]; then
		printf "%s\n" "-> File $CHROOTNAME/boot/liveinitrd.img does not exist. Exiting."
		errorCatch
	fi

	printf "%s\n" "-> Building initrd-$KERNEL_ISO inside chroot"
	# Remove old initrd
	rm -rf "$CHROOTNAME/boot/initrd-$KERNEL_ISO.img"
	rm -rf "$CHROOTNAME"/boot/initrd0.img

	# Remove config before building initrd
	rm -rf "$CHROOTNAME"/etc/dracut.conf.d/60-dracut-isobuild.conf
	rm -rf "$CHROOTNAME"/usr/lib/dracut/modules.d/90liveiso

	# Building initrd
	chroot "$CHROOTNAME" /usr/sbin/dracut -N -f "/boot/initrd-$KERNEL_ISO.img" "$KERNEL_ISO"
	if [ $? != 0 ]; then
		printf "%s\n" "-> Failed creating initrd. Exiting."
		errorCatch
	fi

	# Build the boot kernel initrd in case the user wants it kept
	if [ -n "$BOOT_KERNEL_TYPE" ]; then
		# Building boot kernel initrd
		printf "%s\n" "-> Building initrd-$BOOT_KERNEL_ISO inside chroot"
		chroot "$CHROOTNAME" /usr/sbin/dracut -N -f "/boot/initrd-$BOOT_KERNEL_ISO.img" "$BOOT_KERNEL_ISO"
		if [ $? != 0 ]; then
			printf "%s\n" "-> Failed creating boot kernel initrd. Exiting."
			errorCatch
		fi
	fi

	ln -sf "/boot/initrd-$KERNEL_ISO.img" "$CHROOTNAME/boot/initrd0.img"
}

# Usage: createMemDIsk <target_directory/image_name>.img <grub_support_files_directory> <grub2 efi executable>
# Creates a fat formatted file ifilesystem image which will boot an UEFI system.
createMemDisk () {
	if [ "$EXTARCH" = 'x86_64' ] || [ "$EXTARCH" = 'znver1' ]; then
		ARCHFMT=x86_64-efi
		ARCHPFX=X64
	elif [ "$EXTARCH" = 'aarch64' ]; then
		ARCHFMT=arm64-efi
		ARCHPFX=AA64
	elif echo $EXTARCH |grep -qE '^(i.86|znver1_32|athlon)'; then
		ARCHFMT=i386-efi
		ARCHPFX=IA32
	fi

	ARCHLIB="/usr/lib/grub/$ARCHFMT"
	EFINAME=BOOT"$ARCHPFX.efi"
	printf "%s\n" "-> Setting up UEFI memdisk image."
	GRB2FLS="$ISOROOTNAME/EFI/BOOT"
	# Create memdisk directory
	if [ -e "$WORKDIR/boot/grub" ]; then
		/bin/rm -R "$WORKDIR/boot/grub"
		mkdir -p "$WORKDIR/boot/grub"
	else
		mkdir -p "$WORKDIR/boot/grub"
	fi
	MEMDISKDIR="$WORKDIR/boot/grub"

	# Copy the grub config file to the chroot dir for UEFI support
	# Also set the uuid
	cp -f "$WORKDIR/grub2/start_cfg" "$MEMDISKDIR/grub.cfg"
	sed -i -e "s/%GRUB_UUID%/${GRUB_UUID}/g" "$MEMDISKDIR/grub.cfg"

	# Ensure the old image is removed
	if [ -e "$CHROOTNAME/memdisk_img" ]; then
		rm -f "$CHROOTNAME/memdisk_img"
	fi

	# Create a memdisk img called memdisk_img
	cd "$WORKDIR" || exit
	tar cvf "$CHROOTNAME/memdisk_img" boot

	# Make the image locally rather than rely on the grub2-rpm this allows more control as well as different images for IA32 if required
	# To do this cleanly it's easiest to move the ISO directory containing the config files to the chroot, build and then move it back again
	mv -f "$ISOROOTNAME" "$CHROOTNAME"

	# Job done just remember to move it back again
	chroot "$CHROOTNAME"  /usr/bin/grub2-mkimage -O "$ARCHFMT" -d "$ARCHLIB" -m memdisk_img -o "/ISO/EFI/BOOT/$EFINAME" -p '(memdisk)/boot/grub' \
	 search iso9660 normal memdisk tar boot linux part_msdos part_gpt part_apple configfile help loadenv ls reboot chain multiboot fat udf \
	 ext2 btrfs ntfs reiserfs xfs lvm ata cat test echo multiboot multiboot2 all_video efifwsetup efinet font gfxmenu gfxterm gfxterm_menu \
	 gfxterm_background gzio halt hfsplus jpeg mdraid09 mdraid1x minicmd part_apple part_msdos part_gpt part_bsd password_pbkdf2 png reboot \
	 search search_fs_uuid search_fs_file search_label sleep tftp video xfs lua loopback regexp

	# Move back the ISO filesystem after building the EFI image.
	mv -f "$CHROOTNAME/ISO/" "$ISOROOTNAME"

	# Ensure the ISO image is clear
	if [ -e "$CHROOTNAME/memdisk_img" ]; then
		rm -f "$CHROOTNAME/memdisk_img"
	fi
}

# Usage: createEFI $EXTARCH $ISOCHROOTNAME
# Creates a fat formatted file in filesystem image which will boot an UEFI system.
# PLEASE NOTE THAT THE ISO DIRECTORY IS TEMPORARILY MOVED TO THE CHROOT DIRECTORY FOR THE PURPOSE OF GENERATING THE GRUB IMAGE.
createUEFI() {
	if [ "$EXTARCH" = 'x86_64' ] || [ "$EXTARCH" = 'znver1' ]; then
		ARCHFMT=x86_64-efi
		ARCHPFX=X64
	elif [ "$EXTARCH" = 'aarch64' ]; then
		ARCHFMT=arm64-efi
		ARCHPFX=AA64
	elif echo $EXTARCH |grep -qE '^(i.86|znver1_32|athlon)'; then
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
		rm -rf "$IMGNME"
	fi
	FILESIZE=$(du -s --block-size=512 "$ISOROOTNAME"/EFI | awk '{print $1}')
	EFIFILESIZE=$(( FILESIZE * 2 ))
	PARTTABLESIZE=$(( (2*17408)/512 ))
	EFIDISKSIZE=$((  $EFIFILESIZE + $PARTTABLESIZE + 1 ))

	# Create the image.
	printf "%s\n" "-> Creating EFI image with size $EFIDISKSIZE" 

	# mkfs.vfat can create the image and filesystem directly
	mkfs.vfat -n "OPENMDVASS" -C -F 16 -s 1 -S 512 -M 0xFF -i 22222222 "$IMGNME" "$EFIDISKSIZE"
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
	#SUBSYSTEM=="block", DEVPATH=="/devices/virtual/block/loop*", ENV{ID_FS_UUID}="2222-2222", ENV{UDISKS_PRESENTATION_HIDE}="1", ENV{UDISKS_IGNORE}="1"
	# The indentifiers in the files system image are used to ensure that the rule is unique to this script

	losetup -f  > /dev/null 2>&1
	# Make sure loop device is loaded
	sleep 1
	losetup -f "$IMGNME"
	sleep 1
	if [ $? != 0 ]; then
		printf "%s\n" "-> Failed to mount loopback image." "Exiting."
		errorCatch
	fi
	sleep 1
	mount -t vfat "$IMGNME" /mnt
	if [ $? != 0 ]; then
		printf "%s\n" "-> Failed to mount UEFI image." "Exiting."
		errorCatch
	fi

	# Copy the Grub2 files to the EFI image
	mkdir -p /mnt/EFI/BOOT
	cp -R "$GRB2FLS"/"$EFINAME" /mnt/EFI/BOOT/"$EFINAME"

	# Unmout the filesystem with EFI image
	umount /mnt
	# Be sure to delete the loop device
	losetup -D 
	# Make sure that the image is copied to the ISOROOT
	cp -f  "$IMGNME" "$ISOROOTNAME"
	# Clean up
	kpartx -d "$IMGNME"
	# Remove the EFI directory
	rm -R "$ISOROOTNAME/EFI"
	XORRISO_OPTIONS2=" --efi-boot $EFINAME -append_partition 2 0xef $IMGNME"
}

# Usage: setupGrub2 (chroot directory (~/BASE) , iso directory (~/ISO), configdir (~/omdv-build-iso-<arch>)
# Sets up grub2 to boot /target/dir
setupGrub2() {
	if [ ! -e "$CHROOTNAME"/usr/bin/grub2-mkimage ]; then
		printf "%s\n" "-> Missing grub2-mkimage in installation."
		errorCatch
	fi

	# BIOS Boot and theme support
	# NOTE Themes are used by the EFI boot as well.
	# Copy grub config files to the ISO build directory
	# and set the UUID's
	cp -f "$WORKDIR"/grub2/grub2-bios.cfg "$ISOROOTNAME"/boot/grub/grub.cfg
	sed -i -e "s/%GRUB_UUID%/${GRUB_UUID}/g" "$ISOROOTNAME"/boot/grub/grub.cfg
	cp -f "$WORKDIR"/grub2/start_cfg "$ISOROOTNAME"/boot/grub/start_cfg
	printf "%s\n" "-> Setting GRUB_UUID to ${GRUB_UUID}"
	sed -i -e "s/%GRUB_UUID%/${GRUB_UUID}/g" "$ISOROOTNAME"/boot/grub/start_cfg
	if [ $? != 0 ]; then
		printf "%s\n" "-> Failed to set up GRUB_UUID."
		errorCatch
	fi

	# Add the themes, locales and fonts to the ISO build firectory
	if [ "${TYPE}" != "minimal" ]; then
		mkdir -p "$ISOROOTNAME"/boot/grub "$ISOROOTNAME"/boot/grub/themes "$ISOROOTNAME"/boot/grub/locale "$ISOROOTNAME"/boot/grub/fonts
		cp -a -f "$CHROOTNAME"/boot/grub2/themes "$ISOROOTNAME"/boot/grub/
		cp -a -f "$CHROOTNAME"/usr/share/grub/*.pf2 "$ISOROOTNAME"/boot/grub/fonts/
		sed -i -e "s/title-text.*/title-text: \"Welcome to OpenMandriva Lx $VERSION ${EXTARCH} ${TYPE} BUILD ID: ${BUILD_ID}\"/g" "$ISOROOTNAME"/boot/grub/themes/OpenMandriva/theme.txt > /dev/null 2>&1

		if [ $? != 0 ]; then
			printf "%s\n" "-> WARNING Failed to update Grub2 theme." "Please add a grub theme to my.add if needed."
			# errorCatch
		fi
	fi

	printf "%s\n" "-> Building Grub2 El-Torito image and an embedded image."

	GRUB_LIB=/usr/lib/grub/i386-pc
	GRUB_IMG=$(mktemp)

	# Copy memtest
	cp -rfT "$WORKDIR/extraconfig/memtest" "$ISOROOTNAME/boot/grub/memtest"
	chmod +x "$ISOROOTNAME/boot/grub/memtest"
	# To use an embedded image with our grub2 we need to make the modules available in the /boot/grub directory of the iso.
	# The modules can't be carried in the payload of the embedded image as it's size is limited to 32kb.
	# So we copy the i386-pc modules to the isobuild directory

	mkdir -p "$ISOROOTNAME/boot/grub/i386-pc"
	cp -rf "$CHROOTNAME/usr/lib/grub/i386-pc" "$ISOROOTNAME/boot/grub/"

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
		rm -rf "$ISOROOTNAME/boot/grub/{grub-eltorito,grub-embedded}.img"
	fi

	mv -f "$ISOROOTNAME" "$CHROOTNAME"
	# Job done just remember to move it back again
	# Make the image
	chroot "$CHROOTNAME" /usr/bin/grub2-mkimage -d "$GRUB_LIB" -O i386-pc -o "$GRUB_IMG" -p /boot/grub -c /ISO/boot/grub/start_cfg  iso9660 biosdisk test
	# Move the ISO director back to the working directory
	mv -f "$CHROOTNAME/ISO/" "$WORKDIR"
	# Create bootable hard disk image
	cat "$CHROOTNAME/$GRUB_LIB/boot.img" "$CHROOTNAME/$GRUB_IMG" > "$ISOROOTNAME/boot/grub/grub2-embed_img"
	if [ $? != 0 ]; then
		printf "%s\n" "-> Failed to create Grub2 El-Torito image." "Exiting."
		errorCatch
	fi
	# Create bootable cdimage
	cat "$CHROOTNAME/$GRUB_LIB/cdboot.img" "$CHROOTNAME/$GRUB_IMG" > "$ISOROOTNAME/boot/grub/grub2-eltorito.img"
	if [ $? != 0 ]; then
		printf  "%s\n" "-> Failed to create Grub2 El-Torito image." "Exiting."
		errorCatch
	fi

	XORRISO_OPTIONS1=" -b boot/grub/grub2-eltorito.img -no-emul-boot -boot-info-table --embedded-boot $ISOROOTNAME/boot/grub/grub2-embed_img --protective-msdos-label"

	# Copy SuperGrub iso
	# disable for now
	#	cp -rfT $OURDIR/extraconfig/super_grub2_disk_i386_pc_2.00s2.iso "$ISOROOTNAME"/boot/grub/sgb.iso

	printf "%s\n" "-> End building Grub2 El-Torito image."
	printf "%s\n" "-> Installing liveinitrd for grub2"
set -x	
	if [ -e "$CHROOTNAME/boot/vmlinuz-$BOOT_KERNEL_ISO" ] && [ -e "$CHROOTNAME/boot/liveinitrd.img" ]; then
    cp -a "$CHROOTNAME/boot/vmlinuz-$BOOT_KERNEL_ISO" "$ISOROOTNAME/boot/vmlinuz0"
    cp -a "$CHROOTNAME/boot/liveinitrd.img" "$ISOROOTNAME/boot/liveinitrd.img"
    sed -i "s/%KCC_TYPE%/with ${BOOT_KERNEL_ISO}/" "$ISOROOTNAME"/boot/grub/grub.cfg
        if [ -n "$BOOT_KERNEL_TYPE" ]; then
            cp -a "$CHROOTNAME/boot/vmlinuz-$KERNEL_ISO" "$ISOROOTNAME/boot/vmlinuz1"
            cp -a "$CHROOTNAME/boot/liveinitrd1.img" "$ISOROOTNAME/boot/liveinitrd1.img"
                # If dual kernels are used set up the grub2 menu to show them. This needs extra work
                ALT_KERNEL=`echo "$KERNEL_ISO" | awk -F "-" '{print $2 "-gcc"}'` #Fix this to use shell substitution perhaps"
                sed -i "s/%BOOT_KCC_TYPE%/with ${ALT_KERNEL}/" "$ISOROOTNAME"/boot/grub/grub.cfg
        else
                # Remove the uneeded menu entry
            sed -i '/linux1/,+4 d' "$ISOROOTNAME"/boot/grub/grub.cfg
        fi	
	else
set +x
		printf "%s\n" "-> vmlinuz or liveinitrd does not exists. Exiting."
		errorCatch
	fi

	if [ ! -f "$ISOROOTNAME/boot/liveinitrd.img" ]; then
		printf "%s\n" "-> Missing /boot/liveinitrd.img. Exiting."
		errorCatch
	else
		rm -rf "$CHROOTNAME/boot/liveinitrd.img"
	fi

	XORRISO_OPTIONS="$XORRISO_OPTIONS1 $XORRISO_OPTIONS2"
	rm -rf "$GRUB_IMG"
}

setupISOenv() {
	# Set up default timezone
	printf "%s\n" "-> Setting default timezone"
	ln -sf /usr/share/zoneinfo/Universal "$CHROOTNAME/etc/localtime"

	# try harder with systemd-nspawn
	# version 215 and never has then --share-system option
	#	if (( `rpm -qa systemd --queryformat '%{VERSION} \n'` >= "215" )); then
	#		systemd-nspawn --share-system -D "$CHROOTNAME" /usr/bin/timedatectl set-timezone UTC
	#		# set default locale
	#		printf "%sSetting default localization"
	#		systemd-nspawn --share-system -D "$CHROOTNAME" /usr/bin/localectl set-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8:en_US:en
	#	else
	#		printf "%ssystemd-nspawn does not exists."
	#	fi

	# Create /etc/minsysreqs
	printf "%s\n" "-> Creating /etc/minsysreqs"

	if [ "${TYPE,,}" = "minimal" ]; then
		echo "ram = 512" >> "$CHROOTNAME/etc/minsysreqs"
		echo "hdd = 5" >> "$CHROOTNAME/etc/minsysreqs"
	elif [ "$EXTARCH" = "x86_64" ] || [ "$EXTARCH" = "znver1" ]; then
		echo "ram = 1536" >> "$CHROOTNAME/etc/minsysreqs"
		echo "hdd = 10" >> "$CHROOTNAME/etc/minsysreqs"
	else
		echo "ram = 1024" >> "$CHROOTNAME/etc/minsysreqs"
		echo "hdd = 10" >> "$CHROOTNAME/etc/minsysreqs"
	fi

	# Count imagesize and put in in /etc/minsysreqs
	echo "imagesize = $(du -a -x -b -P "$CHROOTNAME" | tail -1 | awk '{print $1}')" >> "$CHROOTNAME"/etc/minsysreqs

	# Set up displaymanager
	if [[ ( ${TYPE,,} != "minimal" || ${TYPE,,} != "my.add" ) && ! -z ${DISPLAYMANAGER,,} ]]; then
		if [ ! -e "$CHROOTNAME/lib/systemd/system/${DISPLAYMANAGER,,}.service" ]; then
			printf "%s\n" "-> File ${DISPLAYMANAGER,,}.service does not exist. Exiting."
			errorCatch
		fi

		ln -sf "/lib/systemd/system/${DISPLAYMANAGER,,}.service" "$CHROOTNAME/etc/systemd/system/display-manager.service" 2> /dev/null || :

		# (crazy) probably remove that ?
		# Set reasonable defaults
		if  [ -e "$CHROOTNAME/etc/sysconfig/desktop" ]; then
			rm -rf "$CHROOTNAME"/etc/sysconfig/desktop
		fi
	fi

	# Copy some extra config files
	## (crazy) fixme this kind stuff should not be needed this way!
	cp -rfT "$WORKDIR/extraconfig/etc/X11" "$CHROOTNAME"/etc/X11
	# (crazy) booting is handle these now , we start with empty locale.conf
	touch "$CHROOTNAME"/etc/locale.conf
	cp -rfT "$WORKDIR/extraconfig/etc/vconsole.conf" "$CHROOTNAME"/etc/vconsole.conf
	## why ?
	cp -rfT "$WORKDIR/extraconfig/etc/hostname" "$CHROOTNAME"/etc/hostname

	# Add the VirtualBox folder sharing group
	chroot "$CHROOTNAME" /usr/sbin/groupadd -f vboxsf
	chroot "$CHROOTNAME" /usr/sbin/groupadd -f lpadmin

	# Set up live user
	live_user=live
	printf "%s\n" "-> Setting up user ${live_user}"
	chroot "$CHROOTNAME" /usr/sbin/adduser -m -G nopasswd,vboxsf,lpadmin ${live_user}

	# Clear user passwords
	for username in root $live_user; do
		# Kill it as it prevents clearing passwords
		if [ -e "$CHROOTNAME"/etc/shadow.lock ]; then
			rm -rf "$CHROOTNAME"/etc/shadow.lock
		fi
		printf "%s\n" "-> Clearing $username password."
		chroot "$CHROOTNAME" /usr/bin/passwd -f -d $username

		if [ $? != 0 ]; then
			printf "%s\n" "-> Failed to clear $username user password." "Exiting."
			errorCatch
		fi

		chroot "$CHROOTNAME" /usr/bin/passwd -f -u $username
	done

	chroot "$CHROOTNAME" /bin/mkdir -p /home/${live_user}
	chroot "$CHROOTNAME" /bin/cp -rfT /etc/skel /home/${live_user}/
	chroot "$CHROOTNAME" /bin/mkdir -p /home/${live_user}/Desktop
	cp -rfT "$WORKDIR"/extraconfig/etc/skel "$CHROOTNAME"/home/${live_user}/
	chroot "$CHROOTNAME" /bin/mkdir -p /home/${live_user}/.cache
	chroot "$CHROOTNAME" /bin/chown -R ${live_user}:${live_user} /home/${live_user}
	chroot "$CHROOTNAME" /bin/chown -R ${live_user}:${live_user} /home/${live_user}/Desktop
	chroot "$CHROOTNAME" /bin/chown -R ${live_user}:${live_user} /home/${live_user}/.cache
	chroot "$CHROOTNAME" /bin/chmod -R 0777 /home/${live_user}/.local
	# (tpg) support for AccountsService
	chroot "$CHROOTNAME" /bin/mkdir -p /var/lib/AccountsService/users
	chroot "$CHROOTNAME" /bin/mkdir -p /var/lib/AccountsService/icons
	cp -f "$WORKDIR"/data/account-user "$CHROOTNAME"/var/lib/AccountsService/users/${live_user}
	cp -f "$WORKDIR"/data/account-icon "$CHROOTNAME"/var/lib/AccountsService/icons/${live_user}
	chroot "$CHROOTNAME" /bin/sed -i -e "s/_NAME_/${live_user}/g" /var/lib/AccountsService/users/${live_user}

	rm -rf "$CHROOTNAME"/home/${live_user}/.kde4

	if [ "${TYPE,,}" = "plasma" ] || [ "${TYPE,,}" = "plasma-wayland" ]; then
		# disable baloo in live session
		mkdir -p "$CHROOTNAME"/home/${live_user}/.config
		cat >"$CHROOTNAME"/home/${live_user}/.config/baloofilerc << EOF
[Basic Settings]
Indexing-Enabled=false

[General]
first run=false
EOF

		# we really need disable automouter , it still fires udisks2 for some partition types
		[ -f "$CHROOTNAME"/home/${live_user}/.config/kded_device_automounterrc ] && rm -rf "$CHROOTNAME"/home/${live_user}/.config/kded_device_automounterrc
		cat >"$CHROOTNAME"/home/${live_user}/.config/kded_device_automounterrc << EOF
[General]
AutomountEnabled=false
EOF

		# kscreenlocker
		# see: https://forum.openmandriva.org/t/omlx-4-0-pre-alpha-iso-plasma-development-builds/2128/48
		# to manipulate Timeout change value to disable replace Timeout= with -> Autolock=false
		[ -f "$CHROOTNAME"/home/${live_user}/.config/kscreenlockerrc ] && rm -rf "$CHROOTNAME"/home/${live_user}/.config/kscreenlockerrc
		cat >"$CHROOTNAME"/home/${live_user}/.config/kscreenlockerrc << EOF
[Daemon]
Timeout=30
EOF
	fi

	# Enable DM autologin
	if [ "${TYPE,,}" != "minimal" ]; then
		case ${DISPLAYMANAGER,,} in
		"sddm")
			chroot "$CHROOTNAME" sed -i -e "s/^Session=.*/Session=${TYPE,,}.desktop/g" -e 's/^User=.*/User=live/g' /etc/sddm.conf
			if [ "${TYPE,,}" = "lxqt" ]; then
				# (tpg) use maldives theme on LXQt desktop
				chroot "$CHROOTNAME" sed -i -e "s/^Current=.*/Current=maldives/g" /etc/sddm.conf
			fi
			;;
		"gdm")
			chroot "$CHROOTNAME" sed -i -e "s/^AutomaticLoginEnable.*/AutomaticLoginEnable=True/g" -e 's/^AutomaticLogin.*/AutomaticLogin=live/g' /etc/X11/gdm/custom.conf
			;;
		*)
			printf "%s -> ${DISPLAYMANAGER,,} is not supported, autologin feature will be not enabled"
		esac
	fi

	# (crazy) not used ? cannot work like this ?
	pushd "$CHROOTNAME"/etc/sysconfig/network-scripts > /dev/null 2>&1
	for iface in eth0 wlan0; do
		cat > ifcfg-$iface << EOF
DEVICE=$iface
ONBOOT=yes
NM_CONTROLLED=yes
BOOTPROTO=dhcp
EOF
	done
	popd > /dev/null 2>&1

	printf "%s\n" "-> Starting services setup."

	# (crazy) fixme after systemd is fixed..
	# (tpg) enable services based on preset files from systemd and others
	UNIT_DIR="$CHROOTNAME"/lib/systemd/system
	if [ -f "$UNIT_DIR-preset/90-default.preset" ]; then
		PRESETS=("$UNIT_DIR-preset"/*.preset)
		for file in "${PRESETS[@]}"; do
			while read line; do
				if [[ -n "$line" && "$line" != [[:blank:]#]* && "${line,,}" = [[:blank:]enable]* ]]; then
					SANITIZED="${line#*enable}"
					for s_file in $(find "$UNIT_DIR" -type f -name "$SANITIZED"); do
						DEST=$(grep -o 'WantedBy=.*' "$s_file"  | cut -f2- -d'=')
						if [ -n "$DEST" ] && [ -d "$CHROOTNAME/etc/systemd/system" ] && [ ! -e "$CHROOTNAME/etc/systemd/system/$DEST.wants/${s_file#$UNIT_DIR/}" ] ; then
							[ ! -d "/etc/systemd/system/$DEST.wants" ] && mkdir -p "$CHROOTNAME/etc/systemd/system/$DEST.wants"
							printf "%s\n" "-> Enabling ${s_file#$UNIT_DIR/} based on preset file"
							chroot "$CHROOTNAME" /bin/systemctl enable ${s_file#$UNIT_DIR/}
							#ln -sf "/${s_file#$CHROOTNAME/}" "$CHROOTNAME/etc/systemd/system/$DEST.wants/${s_file#$UNIT_DIR/}"
						else
							printf "%s\n" "-> All preset based service already enabled , moving on.."
						fi
					done
				fi
			done < "$file"
		done
	else
		# (crazy) that is wrong
		printf "%s\n" "-> File $UNIT_DIR-preset/90-default.preset does not exist. Installation may be broken"
		errorCatch
	fi

	# Enable services on demand
	# (crazy) WARNING: calamares-locale service need to run for langauage settings grub menu's
	SERVICES_ENABLE=(getty@tty1.service sshd.socket uuidd.socket calamares-locale NetworkManager avahi-daemon irqbalance systemd-timedated systemd-timesyncd systemd-resolved dnf-makecache.timer dnf-automatic.timer dnf-automatic-notifyonly.timer dnf-automatic-download.timer )


	# ( crazy) we cannot symlink/rm for .service,.socket
	# these have , or may have dependecies in the unit file meaning,
	# if you rm/symlink foo it won't enable foo.dbus one or socket , same for disable.
	for i in "${SERVICES_ENABLE[@]}"; do
		if [[ $i  =~ ^.*path$|^.*target$|^.*timer$ ]]; then
			if [ -e "$CHROOTNAME/lib/systemd/system/$i" ]; then
				printf "%s\n" "-> Enabling $i"
				ln -sf "/lib/systemd/system/$i" "$CHROOTNAME/etc/systemd/system/multi-user.target.wants/$i"
			else
				printf "%s\n" "-> Special service $i does not exist. Skipping."
			fi
		else
			printf "%s\n" "-> Enabling $i"
			chroot "$CHROOTNAME" /bin/systemctl enable $i
		fi
	done

	# Disable services
	SERVICES_DISABLE=(pptp pppoe ntpd iptables ip6tables shorewall nfs-server mysqld abrtd mariadb mysql mysqld postfix vboxadd NetworkManager-wait-online systemd-networkd systemd-networkd.socket nfs-utils chronyd udisks2 packagekit mdmonitor)

	for i in "${SERVICES_DISABLE[@]}"; do
		if [[ $i  =~ ^.*path$|^.*target$|^.*timer$ ]]; then
			if [ -e "$CHROOTNAME/lib/systemd/system/$i" ]; then
				printf "%s\n" "-> Disabling $i"
				rm -rf "$CHROOTNAME/etc/systemd/system/multi-user.target.wants/$i"
			else
				printf "%s\n" "-> Special service $i does not exist. Skipping."
			fi
		else
			printf "%s\n" "-> Disabling $i"
			chroot "$CHROOTNAME" /bin/systemctl disable $i
		fi
	done

	# it refuses to die :-)
	[ -e "$CHROOTNAME"/lib/systemd/system/multi-user.target.wants/systemd-networkd.service ] && rm -rf "$CHROOTNAME"/lib/systemd/system/multi-user.target.wants/systemd-networkd.service
	# mask systemd-journald-audit.socket to stop polluting journal with audit spam
	[ ! -e "$CHROOTNAME"/etc/systemd/system/systemd-journald-audit.socket ] && ln -sf /dev/null "$CHROOTNAME"/etc/systemd/system/systemd-journald-audit.socket

	# ATTENTION getty@.service must be always disabled
	[ -e "$CHROOTNAME"/etc/systemd/system/getty.target.wants/getty@.service ] && rm -rf "$CHROOTNAME"/etc/systemd/system/getty.target.wants/getty@.service

	# Calamares installer
	if [ -e "$CHROOTNAME"/etc/calamares/modules/displaymanager.conf ]; then
		# Enable settings for specific desktop environment
		# https://issues.openmandriva.org/show_bug.cgi?id=1424
		sed -i -e "s/.*defaultDesktopEnvironment:.*/defaultDesktopEnvironment:/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"

		## NOTE these sed's need generate valid yaml .. - crazy -
		if [ "${TYPE,,}" = 'plasma' ]; then
			sed -i -e "s/.*executable:.*/    executable: "startkde"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
			sed -i -e "s/.*desktopFile:.*/    desktopFile: "plasma"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
		fi

		if [ "${TYPE,,}" = 'plasma-wayland' ]; then
			sed -i -e "s/.*executable:.*/    executable: "startplasmacompositor"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
			sed -i -e "s/.*desktopFile:.*/    desktopFile: "plasma-wayland"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
		fi

		if [ "${TYPE,,}" = 'mate' ]; then
			sed -i -e "s/.*executable:.*/    executable: "mate-session"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
			sed -i -e "s/.*desktopFile:.*/    desktopFile: "mate"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
		fi

		if [ "${TYPE,,}" = 'lxqt' ]; then
			sed -i -e "s/.*executable:.*/    executable: "lxqt-session"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
			sed -i -e "s/.*desktopFile:.*/    desktopFile: "lxqt"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
		fi

		if [ "${TYPE,,}" = 'icewm' ]; then
			sed -i -e "s/.*desktopFile:.*/    desktopFile: "icewm"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
		fi

		if [ "${TYPE,,}" = 'xfce4' ]; then
			sed -i -e "s/.*executable:.*/    executable: "startxfce4"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
			sed -i -e "s/.*desktopFile:.*/    desktopFile: "xfce"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
		fi
		
        if [ "${TYPE,,}" = 'gnome3' ]; then
			sed -i -e "s/.*executable:.*/    executable: "startgnome3"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
			sed -i -e "s/.*desktopFile:.*/    desktopFile: "gnome3"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
		fi
		if [ "${TYPE,,}" = 'mate' ]; then
			sed -i -e "s/.*executable:.*/    executable: "startmate"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
			sed -i -e "s/.*desktopFile:.*/    desktopFile: "mate"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
		fi
		if [ "${TYPE,,}" = 'user' ]; then 
            sed -i -e "s/.*executable:.*/    executable: "$WMNAME"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
			sed -i -e "s/.*desktopFile:.*/    desktopFile: "$UISONAME"/g" "$CHROOTNAME/etc/calamares/modules/displaymanager.conf"
		fi	
    fi
	#remove rpm db files which may not match the non-chroot environment
	chroot "$CHROOTNAME" rm -f /var/lib/rpm/__db.*

	# Get back to real /etc/resolv.conf
	rm -f "$CHROOTNAME"/etc/resolv.conf
	ln -sf /run/systemd/resolve/resolv.conf "$CHROOTNAME"/etc/resolv.conf
	# set up some default settings
	printf '%s\n' "nameserver 208.67.222.222" "nameserver 208.67.220.220" >> "$CHROOTNAME"/run/systemd/resolve/resolv.conf

	# ldetect stuff
	if [ -x "$CHROOTNAME"/usr/sbin/update-ldetect-lst ]; then
		chroot "$CHROOTNAME" /usr/sbin/update-ldetect-lst
	fi

	# fontconfig cache
	if [ -x "$CHROOTNAME"/usr/bin/fc-cache ]; then
		# set the timestamp on the directories to be a whole second
		# fc-cache looks at the nano second portion which will otherwise be
		# non-zero as we are on ext4, but then it will compare against the stamps
		# on the squashfs live image, squashfs only has second level timestamp resolution
		FCTIME=$(date +%Y%m%d%H%M.%S)
		chroot "$CHROOTNAME" find /usr/share/fonts -type d -exec touch -t "$FCTIME" {} \;
		chroot "$CHROOTNAME" fc-cache -rf
		chroot "$CHROOTNAME" /bin/mkdir -p /root/.cache/fontconfig/
		chroot "$CHROOTNAME" /bin/mkdir -p /${live_user}/.cache/fontconfig/
	fi

	# Rebuild man-db
	if [ -x "$CHROOTNAME"/usr/bin/mandb ]; then
		printf "%s\n" "-> Please wait...rebuilding man page database"
		chroot "$CHROOTNAME" /usr/bin/mandb --quiet
	fi
    
    # Move the rpm cache out of the way for the iso build
	#if [[ "$IN_ABF" = 0  || ( "$IN_ABF" = '1' && -n "$DEBUG" ) ]]; then
	#if [ "$IN_ABF" = 0 ] || [ "$IN_ABF" = '1' ] && [ -n "$DEBUG" ]; then
	mv "$CHROOTNAME"/var/cache/dnf "$WORKDIR"/dnf
	mkdir "$CHROOTNAME"/var/cache/dnf
	#fi
	
	# (crazy) NOTE: this be after last think touched /home/live
	chroot "$CHROOTNAME" /bin/chown -R ${live_user}:${live_user} /home/${live_user}
	# Rebuild linker cache
	chroot "$CHROOTNAME" /sbin/ldconfig

	# Clear tmp
	rm -rf "$CHROOTNAME"/tmp/*
	rm -rf "$CHROOTNAME/1" ||:

	# Generate list of installed rpm packages
	chroot "$CHROOTNAME" rpm -qa --queryformat="%{NAME}\n" | sort > /var/lib/rpm/installed-by-default

	# Remove rpm db files to save some space
	rm -rf "$CHROOTNAME"/var/lib/rpm/__db.*
	echo 'File created by omdv-build-iso. See systemd-update-done.service(8).' \
		| tee "$CHROOTNAME"/etc/.updated >"$CHROOTNAME"/var/.updated
}

# Clean out the backups of passwd, group and shadow
ClnShad() {
	/bin/rm -f "$CHROOTNAME"/etc/passwd- "$CHROOTNAME"/etc/group- "$CHROOTNAME"/etc/shadow-  
	/bin/rm -f "$WORKDIR"/.new
}


createSquash() {
	printf "%s\n" "-> Starting squashfs image build."
	# Before we do anything check if we are a local build
	if [ "$IN_ABF" = '0' ]; then
		# We are so make sure that nothing is mounted on the chroots /run/os-prober/dev/ directory.
		# If mounts exist mksquashfs will try to build a squashfs.img with contents of all  mounted drives
		# It's likely that the img will be written to one of the mounted drives so it's unlikely
		# that there will be enough diskspace to complete the operation.
		if [ -f "$ISOROOTNAME/run/os-prober/dev/*" ]; then
			umount -l "$(echo "$ISOROOTNAME/run/os-prober/dev/*")"
			if [ -f "$ISOROOTNAME/run/os-prober/dev/*" ]; then
				printf "%s\n" "-> Cannot unount os-prober mounts aborting."
				errorCatch
			fi
		fi
        # copy the package lists and and the build options to the chroot
        mkdir ${CHROOTNAME}/.build_info
        cp ${COMMITDIR}/*   ${CHROOTNAME}/.build_info/pkglsts_build_id-${BUILD_ID}
        dnf --installroot "${CHROOTNAME}" list --installed >${CHROOTNAME}/.build_info/installed_pkgs
	fi

	if [ -f "$ISOROOTNAME"/LiveOS/squashfs.img ]; then
		rm -rf "$ISOROOTNAME"/LiveOS/squashfs.img
	fi

	mkdir -p "$ISOROOTNAME"/LiveOS
	# Unmout all stuff inside CHROOT to build squashfs image
	umountAll "$CHROOTNAME"

	# Here we go with local speed ups
	# For development only remove all the compression so the squashfs builds quicker.
	# Give it it's own flag QUICKEN.
	if [ -n "$QUICKEN" ]; then
		mksquashfs "$CHROOTNAME" "$ISOROOTNAME"/LiveOS/squashfs.img -comp ${COMPTYPE} -no-progress -noD -noF -noI -no-exports -no-recovery -b 16384
	else
		mksquashfs "$CHROOTNAME" "$ISOROOTNAME"/LiveOS/squashfs.img -comp ${COMPTYPE}  -no-progress -no-exports -no-recovery -b 16384
	fi
	if [ ! -f  "$ISOROOTNAME"/LiveOS/squashfs.img ]; then
		printf "%s\n" "-> Failed to create squashfs." "Exiting."
		errorCatch
	fi

}

# Usage: buildIso filename.iso rootdir
# Builds an ISO file from the files in rootdir
buildIso() {
	printf "%s\n" "-> Starting ISO build."

	if [ "$IN_ABF" = '1' ]; then
		ISOFILE="$WORKDIR/$PRODUCT_ID.$EXTARCH.iso"
	else
		if [ -z "$OUTPUTDIR" ]; then
			ISOFILE="$WORKDIR/$PRODUCT_ID.$EXTARCH.iso"
		else
			ISOFILE="$OUTPUTDIR/$PRODUCT_ID.$EXTARCH.iso"
		fi
	fi

	if [ ! -x /usr/bin/xorriso ]; then
		printf "%s\n" "-> xorriso does not exists. Exiting."
		errorCatch
	fi

	# Before starting to build remove the old iso. xorriso is much slower to create an iso
	# if it is overwriting an earlier copy. Also it's not clear whether this affects the.
	# contents or structure of the iso (see --append-partition in the man page)
	# Either way building the iso is 30 seconds quicker (for a 1G iso) if the old one is deleted.
	if [ "$IN_ABF" = '0' ] && [ -n "$ISOFILE" ]; then
		printf "%s" "-> Removing old iso."
		rm -rf "$ISOFILE"
	fi
	printf "%s\n" "-> Building ISO with options ${XORRISO_OPTIONS}"

	xorriso -as mkisofs -R -r -J -joliet-long -cache-inodes \
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
		cd "$OUTPUTDIR"
		md5sum "$PRODUCT_ID.$EXTARCH.iso" > "$PRODUCT_ID.$EXTARCH.iso.md5sum"
		sha1sum "$PRODUCT_ID.$EXTARCH.iso" > "$PRODUCT_ID.$EXTARCH.iso.sha1sum"
	else
		pushd "$WORKDIR" > /dev/null 2>&1
		md5sum "$PRODUCT_ID.$EXTARCH.iso" > "$PRODUCT_ID.$EXTARCH.iso.md5sum"
		sha1sum "$PRODUCT_ID.$EXTARCH.iso" > "$PRODUCT_ID.$EXTARCH.iso.sha1sum"
		popd > /dev/null 2>&1
	fi
	mkdir -p "$WORKDIR/results" "$WORKDIR/archives"
	if [ -n "$OUTPUTDIR" ]; then
		mv "$OUTPUTDIR"/*.iso* "$WORKDIR/results/"
	else
		mv "$WORKDIR"/*.iso* "$WORKDIR/results/"
		if [ -d "$WORKDIR/sessrec/" ]; then
		cp -r "$WORKDIR"/sessrec/ "$WORKDIR/archives/"
		fi
	fi


	# If not in ABF move rpms back to the cache directories
	if [ "$IN_ABF" = 0 ] || [ "$IN_ABF" = '1' ] && [ -n "$DEBUG" ]; then
        /bin/rm -rf "$CHROOTNAME"/var/cache/dnf/
		mv -f "$WORKDIR"/dnf "$CHROOTNAME"/var/cache/
	fi

	# Clean chroot
	umountAll "$CHROOTNAME"
}

main "$@"

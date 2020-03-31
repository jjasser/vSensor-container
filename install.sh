#!/bin/sh
set -e
#
# This script is meant for quick & easy install via:
#   sh -c "$(wget -qO - https://packages.darktrace.com/install)"
# or:
#   sh -c "$(curl -sSL https://packages.darktrace.com/install)"
#
# Based on the get.docker.com install script (Apache 2 Licensed)
# Changed to only support our OS, and removed unused sections

repo="vm-stable"
repo_domain=packages.darktrace.com

if [ "$1" = "--cdn" ]; then
    repo_domain=d37dabqmxw3nss.cloudfront.net
    shift
fi

if [ "$1" = "--updateKey" ] || [ "$1" = "--updatekey" ]; then 
    if [ -n "$2" ]; then
        updateKey="$2"
    else
        echo "Missing Agument to --updateKey"
        exit 1
    fi
fi

command_exists() {
	command -v "$@" > /dev/null 2>&1
}

error() {
    echo "ERROR: $@"
    exit 1
}

validate_updateKey() {
    if [ `echo -n "$updateKey" | wc -c` -gt 256 ]; then
        error "Keystring is too long - max 256 chars"
    fi

    if ! echo "$updateKey" | egrep -q "^[a-zA-Z0-9%\.]+:[a-zA-Z0-9%\.]+$" ; then
        echo 'Valid update key is string:string - where each string is [a-zA-Z0-9%.]'
        error "Keystring is not valid"
    fi

    set +e
    if command_exists curl; then
        respcode=`curl -sSf -o /dev/null -w "%{http_code}" "https://${updateKey}@$repo_domain/ubuntu/"`
        exitcode=$?
    elif command_exists wget; then
        respcode=`wget -qS "https://${updateKey}@$repo_domain/ubuntu/" | grep "HTTP/" | awk '{print $2}'`
        exitcode=$?
    else
        #don't support just busybox
        return
    fi
    set -e
    if [ "$respcode" -ge 500 ]; then
        error "Server is having issues, please try again later, or report to support@darktrace.com"
    elif [ "$respcode" -eq 401 ]; then
        error "updateKey not recognised, please double check, or report to support@darktrace.com"
    elif [ "$respcode" -eq 407 ]; then
        error "Proxy auth failed"
    elif [ "$respcode" -ge 400 ]; then
        error "Cannot connecto to $repo_domain successfully"
    elif [ "$exitcode" -ne 0 ]; then
        error "Issue connecting to $repo_domain"
    fi

}

get_updateKey() {
    count=1
    echo "An updateKey allows software updates from $repo_domain"
    echo "This can be obtained from your Darktrace account manager"
    echo
    while true
    do
        ##Get customer name if empty
        if [ -z "$updateKey" ]
        then
            echo -n "Please Enter your updateKey "
            read updateKey
        fi
        count=$((count+1))
        ##Exit if name entered
        if [ -n "$updateKey" ]
        then
            validate_updateKey
            return
        fi
    done

}

# Check if this is a forked Linux distro
check_forked() {

	# Check for lsb_release command existence, it usually exists in forked distros
	if command_exists lsb_release; then
		# Check if the `-u` option is supported
		set +e
		lsb_release -a -u > /dev/null 2>&1
		lsb_release_exit_code=$?
		set -e

		# Check if the command has exited successfully, it means we're in a forked distro
		if [ "$lsb_release_exit_code" = "0" ]; then
			# Print info about current distro
			cat <<-EOF
			You're using '$lsb_dist' version '$dist_version'.
			EOF

			# Get the upstream release info
			lsb_dist=$(lsb_release -a -u 2>&1 | tr '[:upper:]' '[:lower:]' | grep -E 'id' | cut -d ':' -f 2 | tr -d '[[:space:]]')
			dist_version=$(lsb_release -a -u 2>&1 | tr '[:upper:]' '[:lower:]' | grep -E 'codename' | cut -d ':' -f 2 | tr -d '[[:space:]]')

			# Print info about upstream distro
			cat <<-EOF
			Upstream release is '$lsb_dist' version '$dist_version'.
			EOF
		else
			if [ -r /etc/debian_version ] && [ "$lsb_dist" != "ubuntu" ]; then
				# We're Debian and don't even know it!
				lsb_dist=debian
				dist_version="$(cat /etc/debian_version | sed 's/\/.*//' | sed 's/\..*//')"
				case "$dist_version" in
					8|'Kali Linux 2')
						dist_version="jessie"
					;;
					7)
						dist_version="wheezy"
					;;
				esac
			fi
		fi
	fi
}


add_base_ubuntu_repos() {
    cat << EOF | sudo tee -a /etc/apt/sources.list.d/upstream.list > /dev/null
deb http://archive.ubuntu.com/ubuntu ${dist_version} main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu ${dist_version}-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu ${dist_version}-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu ${dist_version}-security main restricted universe multiverse
 
EOF
    echo "Added sources to /etc/apt/sources.list.d/upstream.list"
    ( set -x; $sh_c 'apt-get update' )
}


do_install() {
    if [ -f /etc/darktrace/config.cfg ]; then
        error "Darktrace vSensor already installed"
    fi
	case "$(uname -m)" in
		*64)
			;;
		*)
            error "you are not using a 64bit platform. Darktrace vSensor currently only supports 64bit platforms."
			;;
	esac

	user="$(id -un 2>/dev/null || true)"

	sh_c='sh -c'
	if [ "$user" != 'root' ]; then
		if command_exists sudo; then
			sh_c='sudo -E sh -c'
		elif command_exists su; then
			sh_c='su -c'
		else
            error 'this installer needs the ability to run commands as root. We are unable to find either "sudo" or "su" available to make this happen.'
		fi
	fi

	curl=''
	if command_exists curl; then
		curl='curl -sSL'
	elif command_exists wget; then
		curl='wget -qO-'
	elif command_exists busybox && busybox --list-modules | grep -q wget; then
		curl='busybox wget -qO-'
	fi

	# perform some very rudimentary platform detection
	lsb_dist=''
	dist_version=''
	if command_exists lsb_release; then
		lsb_dist="$(lsb_release -si)"
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/lsb-release ]; then
		lsb_dist="$(. /etc/lsb-release && echo "$DISTRIB_ID")"
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/debian_version ]; then
		lsb_dist='debian'
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/fedora-release ]; then
		lsb_dist='fedora'
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/oracle-release ]; then
		lsb_dist='oracleserver'
	fi
	if [ -z "$lsb_dist" ]; then
		if [ -r /etc/centos-release ] || [ -r /etc/redhat-release ]; then
			lsb_dist='centos'
		fi
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/os-release ]; then
		lsb_dist="$(. /etc/os-release && echo "$ID")"
	fi

	lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"

	case "$lsb_dist" in

		ubuntu)
			if command_exists lsb_release; then
				dist_version="$(lsb_release --codename | cut -f2)"
			fi
			if [ -z "$dist_version" ] && [ -r /etc/lsb-release ]; then
				dist_version="$(. /etc/lsb-release && echo "$DISTRIB_CODENAME")"
			fi
		;;

		debian)
			dist_version="$(cat /etc/debian_version | sed 's/\/.*//' | sed 's/\..*//')"
			case "$dist_version" in
				8)
					dist_version="jessie"
				;;
				7)
					dist_version="wheezy"
				;;
			esac
		;;

		oracleserver)
			# need to switch lsb_dist to match yum repo URL
			lsb_dist="oraclelinux"
			dist_version="$(rpm -q --whatprovides redhat-release --queryformat "%{VERSION}\n" | sed 's/\/.*//' | sed 's/\..*//' | sed 's/Server*//')"
		;;

		fedora|centos)
			dist_version="$(rpm -q --whatprovides redhat-release --queryformat "%{VERSION}\n" | sed 's/\/.*//' | sed 's/\..*//' | sed 's/Server*//')"
		;;

		*)
			if command_exists lsb_release; then
				dist_version="$(lsb_release --codename | cut -f2)"
			fi
			if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
				dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
			fi
		;;


	esac

	# Check if this is a forked Linux distro
	check_forked

    if [ "$lsb_dist" != "ubuntu" ]; then
        error "Only Ubuntu precise 12.04 or xenial 16.04 are supported as a base OS"
    fi
    if [ "$dist_version" != "precise" ]; then
        if [ "$dist_version" != "xenial" ]; then
            error "Only Ubuntu precise 12.04 or xenial 16.04 are supported as a base OS"
        fi
    fi

    export DEBIAN_FRONTEND=noninteractive

    did_apt_get_update=
    apt_get_update() {
        if [ -z "$did_apt_get_update" ]; then
            ( set -x; $sh_c 'apt-get update' )
            did_apt_get_update=1
        fi
    }

    apt_get_update
    if ! apt-cache policy coreutils | grep -v var/lib/dpkg/status | grep $dist_version ; then 
        echo "Unable to pull dependencies from Ubuntu $dist_version repositories"
        #if not interactive, exit here
        if ! tty -s; then
            echo "Debug output of \"apt-cache policy coreutils\""
            apt-cache policy coreutils
            echo "Missing base Ubuntu archives, please add to sources.list"
            exit 1
        fi
        read -p "Adding the Ubuntu archives to your source list is a requirement for installing the vSensor. Would you like to add Ubuntu archives to your apt source list? yY " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            add_base_ubuntu_repos
        else
            exit 1
        fi
    fi

    # install apparmor utils if they're missing and apparmor is enabled in the kernel
    if [ "$(cat /sys/module/apparmor/parameters/enabled 2>/dev/null)" = 'Y' ]; then
        if ! command -v apparmor_parser >/dev/null 2>&1; then
            echo 'apparmor is enabled in the kernel, but apparmor_parser missing'
            ( set -x; $sh_c 'sleep 1; apt-get install -y -q apparmor' )
        fi
    fi

    if [ ! -e /usr/lib/apt/methods/https ]; then
        ( set -x; $sh_c 'sleep 1; apt-get install -y -q apt-transport-https ca-certificates' )
    fi
    if [ -z "$curl" ]; then
        ( set -x; $sh_c 'sleep 1; apt-get install -y -q curl ca-certificates' )
        curl='curl -sSL'
    fi
    #enter UpdateKey
    get_updateKey

    #mv sources.list as darktrace-packages-repo package will hide it
    (
    set -x
    $sh_c "$curl https://$repo_domain/packages.pub | sudo apt-key add -"
    $sh_c "$curl https://$repo_domain/packages-7CBE2079.pub | sudo apt-key add -"
    $sh_c "mkdir -p /etc/apt/sources.list.d"
    $sh_c "if [ -f /etc/apt/sources.list ]; then mv /etc/apt/sources.list /etc/apt/sources.list.d/sources.list; fi"
    $sh_c "echo deb [arch=$(dpkg --print-architecture)] https://${updateKey}@$repo_domain/apt ${dist_version} ${repo} > /etc/apt/sources.list.d/darktrace-archive-vm.list"
    $sh_c 'sleep 3; apt-get update; apt-get install -y -q darktrace-vmprobe'
    $sh_c "sleep 1; sed -i \"/\[confconsole\]/ a updatekey = ${updateKey}\" /etc/darktrace/config.cfg"
    $sh_c 'if uname -r | grep -q "\-gcp"; then if type set_sniff_primary_interface.sh >/dev/null 2>&1; then set_sniff_primary_interface.sh 1; fi; fi'
    $sh_c 'sed -i "/RUN_FIRSTBOOT=true/d" /etc/default/inithooks'
    $sh_c 'sleep 1; /usr/lib/inithooks/firstboot.d/15random-uuid'
    $sh_c 'sleep 1; if [ -x /usr/lib/inithooks/firstboot.d/90chronicle ]; then /usr/lib/inithooks/firstboot.d/90chronicle; fi'
    $sh_c 'sleep 1; /usr/lib/inithooks/run'
    $sh_c 'sleep 1; all-services.sh restart'

    )
    echo "Finished, run \"sudo confconsole\" to set up"
    exit 0

}

# wrapped up in a function so that we have some protection against only getting
# half the file during "curl | sh"
do_install
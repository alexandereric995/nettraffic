#!/usr/bin/env sh
# edit by Alexander Eric@Eric Lapin

trap 'exit_code=$?; [ $exit_code -ne 0 ] && echo "Error on line ${LINENO} of ${0}"; exit $exit_code' EXIT;
set -o errexit -o nounset -o pipefail;


. build/functions.sh

topscript='' TC_DIR=''
topscript="$(realpath "$0")"
TC_DIR="$(dirname "$(dirname "$topscript")")"
export TC_DIR
if [ -z "$TC_DIR" ] || ! cd "$TC_DIR"; then
	echo "Could not cd TC_DIR ${TC_DIR}";
	exit 1;
fi;

if [ $# -gt 0 ]; then
	projects="$*"
else
	# get all subdirs containing build/build_rpm.sh
	projects_to_build='*/build/build_rpm.sh'
	# Always build tarball when building everything..
	projects=tarball
	for p in ${projects_to_build}; do
		p="${p%%/*}"
		if [ "$p" != "traffic_monitor_golang" ]; then
			projects="${projects} ${p}"
		fi
	done
fi


badproj=''
goodproj=''
for p in ${projects}; do
	if [ "$p" = tarball ]; then
		if isInGitTree; then
			echo "-----  Building tarball ..."
			checkEnvironment -e rpmbuild
			tarball="$(createTarball "$TC_DIR")"
			ls -l "$tarball"
		else
			echo "---- Skipping tarball creation"
		fi
		continue
	fi
	if [ "$p" = docs ]; then
		if isInGitTree; then
			echo "-----  Building docs ..."
			checkEnvironment -i python3,make, -e rpmbuild
			( cd docs
			make html
			)
			tarball=$(createDocsTarball "${TC_DIR}")
			ls -l "$tarball"
		else
			echo "---- Skipping docs creation"
		fi
		continue
	fi
	# strip trailing /
	p="${p%/}"
	bldscript="${p}/build/build_rpm.sh"
	if [ ! -x "$bldscript" ]; then
		echo "$bldscript not found"
		badproj="${badproj} ${p}"
		continue
	fi

	echo "-----  Building $p ..."
	if $bldscript; then
		goodproj="${goodproj} ${p}"
	else
		echo "${p} failed: ${bldscript}"
		badproj="${badproj} ${p}"
	fi
done

if [ "$(echo "${goodproj}" | wc -w)" -ne 0 ]; then
	echo "The following subdirectories built successfully: "
	for p in ${goodproj}; do
		echo "   $p"
	done
	echo "See $(pwd)/dist for newly built rpms."
fi

if [ "$(echo "${badproj}" | wc -w)" -ne 0 ]; then
	echo "The following subdirectories had errors: "
	for p in ${badproj}; do
		echo "   $p"
	done
	exit 1
fi

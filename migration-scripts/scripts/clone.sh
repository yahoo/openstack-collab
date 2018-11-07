#!/usr/bin/env bash
# Copyright 2018, Oath Inc.
# Licensed under the terms of the MIT license. See LICENSE file for terms.

set -Eexo pipefail

# Usage:
# ------
# ./clone.sh [option]
#  
#  option:
#    -h, --help:  show brief help
#    -b, --baremetal: Include the repositories needed for baremetal
#
# Requirements:
# -------------
# 1. Must have access to github.com
# 2. Must be on RHEL6 or RHEL7

# Purpose/Background:
# -------------------
# This script is used to clone down all repositories that are required for the
# DB migration from juno to ocata. It will also build all of the required
# virtualenvs. The output of this script is a tarball called 'build.tar.gz'.
 
# This script takes around 30-40 (60 for --baremetal) minutes to run. It is
# useful to have this done and the build.tar.gz file available, prior to
# the actual start of a DB migration.
#
# After this script is finished:
# - Copy this tarball to the DB host of the target migration cluster
#   before starting the migration (via e.g. the 'cp_build.sh' script).
# - Unzip the tarball with 'tar -xzf build.tar.gz'. Unzipping the
#   tarball will create a 'build' directory.
# - Run the migration script 'do_migration.sh' from within the directory
#   that holds the build directory.

usage() {
  echo "Usage:"
  echo "$0 [option]"
  echo "  option:"
  echo "    -h, --help:      Display this help message"
  echo "    -b, --baremetal: Include repository for baremetal (ironic)" 
}

if ! full_release=$(cat /etc/redhat-release) ; then
    echo "This script must be run on a RHEL machine"
    exit 1
fi

set -e

baremetal=0

while (( "$#" )); do
  case "$1" in
    -b|--baremetal)
      baremetal=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*|--*=) # unsupported flags
      echo "Error: Unsupported flag '$1'" >&2
      exit 1
      ;;
    *) # unsupported positional arguments
      echo "Error: Unsupported positional argument '$1'" >&2
      exit 1
      ;;
  esac
done

echo "RHEL release from /etc/redhat-release: $full_release"
case $full_release in
    *"release 6"*)
        sudo yum install -y mysql-devel;;
    *"release 7"*)
        sudo yum install -y mariadb-devel;;
esac
sudo yum install -y git libxml2-devel libxslt-devel libffi-devel openssl-devel libvirt-devel

# Make sure python interpreter and virtualenv are available
sudo yum install -y python python-pip
export PIP_REQUIRE_VIRTUALENV=false
sudo pip install virtualenv
export PIP_REQUIRE_VIRTUALENV=true

rm -rf ~/.cache/pip

components="keystone nova glance neutron"
releases="kilo liberty mitaka newton ocata"

if [ ! -e build ]; then
  mkdir build
fi
(
    cd build
    build_dir=$(pwd)
    for comp in $components ; do
        (
            [ -e "${comp}" ] || git clone "https://github.com/openstack/${comp}.git" "${comp}"
            for release in ${releases} ; do
                dir_name="${comp}-${release}"
                cd "$comp";
                if git branch -a | grep -q stable/${release} ; then
                    tag="stable/${release}"
                else
                    tag="${release}-eol"
                fi
                cd ..
                echo "Processing $dir_name..."
                (
                    cd "${comp}"
                    git checkout "${tag}"
                )
                cp -r "${comp}" "${dir_name}"
                (
                    venv_name="venv-${dir_name}"
                    virtualenv "${venv_name}"
                    source ${venv_name}/bin/activate
                    cd "${dir_name}"
                    # Before installing we need to make a couple changes to the upper-constraints file
                    if [ "${release}" == "newton" ] ; then
                        up_cons_tag='stable/newton'
                    else
                        up_cons_tag="$tag"
                    fi
                    up_cons_file=$dir_name-upper-constraints.txt
                    curl "https://git.openstack.org/cgit/openstack/requirements/plain/upper-constraints.txt?h=${up_cons_tag}" | grep -v '^aioeventlet' | grep -v '^cryptography=' | grep -v '^pyOpenSSL=' | grep -v '^cffi=' | grep -v 'SQLAlchemy' | grep -v 'MySQL-python' | grep -v 'PyMySQL' | grep -v 'alembic' > "${up_cons_file}"
                    echo "aioeventlet===0.5.2" >> "${up_cons_file}"
                    if [ "${release}" == "kilo" ] ; then
                        echo "Changing i18n version for kilo release"
                        grep -v 'oslo.i18n' "${up_cons_file}" | grep -v 'oslo.db' | grep -v '^kombu' > "${up_cons_file}-BAK"
                        echo "oslo.i18n===1.7.0" >> "${up_cons_file}-BAK"
                        echo "oslo.db===1.7.0" >> "${up_cons_file}-BAK"
                        echo "kombu===3.0.30" >> "${up_cons_file}-BAK"
                        cp "${up_cons_file}-BAK" "${up_cons_file}"
                    fi
                    # install package and mysql bindings using modified upper-constraints
                    pip install . MySQL-python PyMySQL -c "${up_cons_file}"
                    deactivate
                )
            done
        )
        rm -rf "${comp}"
    done

    if [ "$baremetal" == 1 ]; then
        # NOTE(rloo): For the ironic DB migration, we only need the ocata
        # version of our modified ironic. Instead of adding a bunch of ifs
        # above to handle this case, the relevant bits are copy/pasted,
        # because this is a one-off and will not be needed for future
        # (post-ocata) migrations.
        #
        # This adds 'ironic-ocata' and 'venv-ironic-ocata' directories.
        comp="ironic"
        release="ocata"
        git clone "https://github.com/openstack/${comp}.git" "${comp}"
        dir_name="${comp}-${release}"
        branch="stable/${release}"
        echo "Processing $dir_name..."
        (
            cd "${comp}"
            git checkout "${branch}"
        )
        cp -r "${comp}" "${dir_name}"
        (
            venv_name="venv-${dir_name}"
            virtualenv "${venv_name}"
            source ${venv_name}/bin/activate
            cd "${dir_name}"
            up_cons_file=$dir_name-upper-constraints.txt
            cp upper-constraints.txt "${up_cons_file}"
            # install package and mysql bindings using upper-constraints
            pip install . MySQL-python PyMySQL -c "${up_cons_file}"
            deactivate
        )
        rm -rf "${comp}"
    fi
)
echo "Zipping all repos into a single tarball..."
tar -czf build.tar.gz build
echo "Cleaning..."
rm -rf build
echo "Success! You can unpack the tarball with the following command: tar -xzf build.tar.gz"

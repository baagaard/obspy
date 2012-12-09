#!/bin/bash
#-------------------------------------------------------------------
# Filename: deb__build_debs.sh
#  Purpose: Build Debian packages for ObsPy 
#   Author: Moritz Beyreuther, Tobias Megies
#    Email: tobias.megies@geophysik.uni-muenchen.de
#
# Copyright (C) 2011-2012 ObsPy Development Team
#---------------------------------------------------------------------

DEBVERSION=1
DATE=`date +"%a, %d %b %Y %H:%M:%S %z"`

# Setting PATH to correct python distribution, avoid to use virtualenv
export PATH=/usr/bin:/usr/sbin:/bin:/sbin
CODENAME=`lsb_release -cs`
# the lsb-release package in raspbian wheezy
# (http://www.raspberrypi.org/downloads) does not report the codename
# correctly, so fix this
if [ "$CODENAME" == "n/a" ] && [ `arch` == "armv6l" ]; then CODENAME=wheezy; fi
BUILDDIR=/tmp/python-obspy_build
PACKAGEDIR=$BUILDDIR/packages
GITDIR=$BUILDDIR/git

# deactivate, else each time all packages are removed
rm -rf $BUILDDIR
mkdir -p $PACKAGEDIR
git clone https://github.com/obspy/obspy.git $GITDIR

# Build ObsPy Packages
TAGS="`git tag | tail -1` master"
for TAG in $TAGS; do
    echo "#### Working on $TAG"
    cd $GITDIR
    git clean -fxd
    git checkout $TAG
    git clean -fxd
    # remove dependencies of distribute for obspy.core
    # distribute is not packed for python2.5 in Debian
    # Note: the space before distribute is essential
    # Note: also makes problems in python2.6 because it wants to install a more
    # recent distribute
    ex setup.py << EOL
g/ distribute_setup/d
wq
EOL
    # get version number from the tag, the debian version
    # has to be increased manually if necessary.
    VERSION=`python -c "\
import sys
import os
UTIL_PATH = os.path.abspath(os.path.join('$GITDIR', 'obspy', 'core', 'util'))
sys.path.append(UTIL_PATH)
from base import _getVersionString
print _getVersionString()"`
    # our package is not really dirty, just minor changes for packaging applied
    VERSION=${VERSION//-dirty/}
    # the commented code shows how to update the changelog
    # information, however we do not do it as it hard to
    # automatize it for all packages in common
    # dch --newversion ${VERSION}-$DEBVERSION "New release" 
    # just write a changelog template with only updated version info
    cat > debian/changelog << EOF
python-obspy (${VERSION}-${DEBVERSION}~${CODENAME}) unstable; urgency=low

EOF
    sed "s/^/  /" CHANGELOG.txt >> debian/changelog
    cat >> debian/changelog << EOF

 -- ObsPy Development Team <devs@obspy.org>  $DATE
EOF
    # dh doesn't know option python2 in lucid
    if [ $CODENAME = "lucid" ]
        then
        ex ./debian/rules << EOL
%s/--with=python2/ /g
g/dh_numpy/d
wq
EOL
    fi
    # adjust dh compatibility for older dh versions
    if [ $CODENAME = "lucid" ]
        then
        echo "7" > ./debian/compat
    elif [ $CODENAME = "squeeze" ]
        then
        echo "8" > ./debian/compat
    fi
    # build the package
    fakeroot ./debian/rules clean build binary
    mv ../python-obspy_*.deb $PACKAGEDIR/
done

# run lintian to verify the packages
for PACKAGE in `ls $PACKAGEDIR/python-obspy_*.deb`; do
    echo "#### lintian for $PACKAGE"
    #lintian -i $PACKAGE # verbose output
    lintian $PACKAGE
done
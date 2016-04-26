#! /bin/sh
# Configure your paths and filenames
SOURCEBINPATH=.
SOURCEBIN=init.lua
SOURCEDOC=README.md
DEBFOLDER=awesome-revelation

DEBVERSION=$(date +%Y%m%d)

TOME="$( cd "$( dirname "$0" )" && pwd )"
cd $TOME

git pull origin master

DEBFOLDERNAME="$TOME/../$DEBFOLDER-$DEBVERSION"
DEBPACKAGENAME=$DEBFOLDER\_$DEBVERSION

rm -rf $DEBFOLDERNAME
#Create your scripts source dir
mkdir $DEBFOLDERNAME

# Copy your script to the source dir
cp $TOME $DEBFOLDERNAME/
cd $DEBFOLDERNAME

pwd

# Create the packaging skeleton (debian/*)
dh_make -s --indep --createorig

mkdir -p debian/tmp/usr/share/doc/$DEBFOLDER/
mkdir -p debian/tmp/etc/xdg/revelation
cp init.lua debian/tmp/etc/xdg/revelation
cp README.md debian/tmp/usr/share/doc/$DEBFOLDER/

# Remove make calls
grep -v makefile debian/rules > debian/rules.new 
mv debian/rules.new debian/rules 

# debian/install must contain the list of scripts to install 
# as well as the target directory
echo $SOURCEBIN etc/xdg/awesome/revelation > debian/install 
echo $SOURCEDOC usr/share/doc/$DEBFOLDER >> debian/install

echo "Source: $DEBFOLDER
Section: unknown
Priority: optional
Maintainer: cmotc <cmotc@openmailbox.org>
Build-Depends: debhelper (>= 9)
Standards-Version: 3.9.5
Homepage: <insert the upstream URL, if relevant>
#Vcs-Git: git@github.com:cmotc/awesome-revelation
#Vcs-Browser: https://www.github.com/cmotc/awesome-revelation

Package: $DEBFOLDER
Architecture: all
Depends: awesome (>= 3.5), \${misc:Depends}
Description: Show all clients all screens in Awesome window manager
 Displays all clients on all screens at once in Awesome Window Manager." > debian/control 
 
# Remove the example files
rm debian/*.ex
rm debian/*.EX

# Build the package.
# You  will get a lot of warnings and ../somescripts_0.1-1_i386.deb
debuild -us -uc > ../log 

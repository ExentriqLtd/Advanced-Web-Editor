#!/bin/sh
ATOM_FOLDER=~/.atom/packages
PACKAGE_FOLDER="$ATOM_FOLDER/mapr-website"

rm -rf $PACKAGE_FOLDER
mkdir -p $PACKAGE_FOLDER
cp -R ./ $PACKAGE_FOLDER

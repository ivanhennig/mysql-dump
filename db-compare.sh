#!/bin/bash

# ------------------------------------------------------------
# Copyright 2018 Blast Technologies
#
# https://github.com/blasttech/mysql-dump/LICENSE
# ------------------------------------------------------------

# ----------
# Compare dumps script
#
# Usage:
# ./db-compare.sh -b <BRANCH> -s ./folder1 -d ./folder2 -o ./output.log
#
# ----------

# ----------
# Stop on error
# ----------
set -e

# ----------
# Parsing options
# ----------
show_options_exit()
{
    echo "Usage  : $0 -f ./arena-db -b <BRANCH> -s ./arena-db/folder1 -d ./arena-db/folder2 -o ./output.log"
    echo "Options:"
    echo " -f Git folder"
    echo " -b Branch name. Default: master"
    echo " -s Source folder to compare"
    echo " -d Destination folder to compare"
    echo " -o Output file"
    exit 1
}

WORKFOLDER=""
BRANCH="master"
OUTPUT="output.log"
SRCFOLDER=""
DSTFOLDER=""
while getopts ":f:b:s:d:o:" opt; do
  case $opt in
    f) WORKFOLDER="${OPTARG}";;
    b) BRANCH="${OPTARG}";;
    s) SRCFOLDER="${OPTARG}";;
    d) DSTFOLDER="${OPTARG}";;
    o) OUTPUT="${OPTARG}";;
    \?)
        echo "Invalid option: -$OPTARG" >&2 
        show_options_exit
    ;;
  esac
done

if [ "$WORKFOLDER" = "" ]
then
    echo "Git folder couldn't be empty" >&2 
    show_options_exit
fi

if [ "$SRCFOLDER" = "" ]
then
    echo "Source folder couldn't be empty" >&2 
    show_options_exit
fi

if [ "$DSTFOLDER" = "" ]
then
    echo "Destination folder couldn't be empty" >&2 
    show_options_exit
fi
# ----------
# Downloads the latest from remote without trying to merge or rebase anything.
# ----------
git -C $WORKFOLDER fetch --all
git -C $WORKFOLDER reset --hard origin/$BRANCH

# ----------
# Comparing folders
# ----------
diff -qr $SRCFOLDER $DSTFOLDER > $OUTPUT


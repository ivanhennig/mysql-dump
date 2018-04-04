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
OUTPUT="output.log"
while getopts "bsd:o" opt; do
echo $opt
  case $opt in
    b) BRANCH="${OPTARG}";;
    s) SRCFOLDER="${OPTARG}";;
    d) DSTFOLDER="${OPTARG}";;
    o) OUTPUT="${OPTARG}";;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      echo "Usage  : $0 -b <BRANCH> -s ./folder1 -d ./folder2 -o ./output.log"
      echo "Options:"
      echo " -b Branch name"
      echo " -s Folder1 to compare"
      echo " -d Folder2 to compare"
      echo " -o Output file"
      exit 1
      ;;
  esac
done

# ----------
# Downloads the latest from remote without trying to merge or rebase anything.
# ----------
git fetch origin/$BRANCH
git reset --hard FETCH_HEAD

# ----------
# Comparing folders
# ----------
diff -qr $SRCFOLDER $DSTFOLDER > $OUTPUT


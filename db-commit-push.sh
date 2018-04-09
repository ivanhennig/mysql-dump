#!/bin/bash

# ------------------------------------------------------------
# Copyright 2018 Blast Technologies
#
# https://github.com/blasttech/mysql-dump/LICENSE
# ------------------------------------------------------------

# ----------
# Stage, commit and push
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
    echo "Usage  : $0 -f ./arena-db/somefolder"
    echo "Options:"
    echo " -f Dump folder to submit"
    exit 1
}

WORKFOLDER=""
while getopts ":f:b:s:" opt; do
  case $opt in
    f) WORKFOLDER="${OPTARG}";;
    \?)
        echo "Invalid option: -$OPTARG" >&2 
        show_options_exit
    ;;
  esac
done

if [ "$WORKFOLDER" = "" ]
then
    echo "Dump folder couldn't be empty" >&2 
    show_options_exit
fi

# ----------
# Stage files, commit and push.
# ----------
cd $WORKFOLDER
git pull -q
git add .
git add ./*
git commit -m "Dump"
git push
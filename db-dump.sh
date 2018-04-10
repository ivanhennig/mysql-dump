#!/bin/bash

# ------------------------------------------------------------
# Copyright 2018 Blast Technologies
#
# https://github.com/blasttech/mysql-dump/LICENSE
# ------------------------------------------------------------

# ----------
# Dump database script
#
# Usage:
# ./db-dump.sh dbname connectionfile all/tables/views/procs
#
# The connection file should be in the format:
#
# [client]
# port=db_port_number
# user=db_user_name
# password=db_password
# host=db_server_ip
#
# ----------

# ----------
# Stop on error
# ----------
set -e

# ----------
# Parsing options
# ----------
WITH_GZIP=1
while getopts ":z" opt; do
  case $opt in
    z)
      WITH_GZIP=0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

# ----------
# Check command line arguments
# ----------
if [ "$#" -lt 4 ]; then
    echo "Usage  : $0 <OPTIONS> <DB_NAME> <CONNECTION> <BASE_BACKUP_DIRECTORY> <FOLDERS>"
    echo "Options:"
    echo " -z Don't compress the dumps"
    exit 1;
fi

# ----------
# Assign command line arguments
# ----------
if [ $WITH_GZIP -eq 1 ]; then
    echo "Enabling gzip"
    GZIP="$(which gzip)"
    OUTPUT_EXT=".sql.gz"
    DB="$1"
    CONFIG="$2"
    DUMP_DIR="$3"
    DUMP_FOLDERS="$4"
else
    echo "Disabling gzip"
    GZIP="$(which cat)"
    OUTPUT_EXT=".sql"
    DB="$2"
    CONFIG="$3"
    DUMP_DIR="$4"
    DUMP_FOLDERS="$5"
fi
# ----------
# Attempt to create dump directory if not present
# ----------
if [ ! -d $DUMP_DIR ]; then
    mkdir $DUMP_DIR
    if [ ! -d $DUMP_DIR ]; then
        echo "Failed to create backup dir $DUMP_DIR"
        exit 1;
    fi
fi

# ----------
# mysql & mysqldump setup
# ----------
MYSQL="mysql --defaults-extra-file=$CONFIG $DB"
MYSQLDUMP="mysqldump --defaults-extra-file=$CONFIG $DB"

# ----------
# Check for dump folders, create if not found
# ----------
if [ ! -d "$DUMP_DIR/$DB" ]; then
    mkdir "$DUMP_DIR/$DB"
fi
if [ ! -d "$DUMP_DIR/$DB/tables" ]; then
    mkdir "$DUMP_DIR/$DB/tables"
fi
if [ ! -d "$DUMP_DIR/$DB/views" ]; then
    mkdir "$DUMP_DIR/$DB/views"
fi
if [ ! -d "$DUMP_DIR/$DB/procs" ]; then
    mkdir "$DUMP_DIR/$DB/procs"
fi

# ----------
# Dump tables
# ----------
if [ "$DUMP_FOLDERS" = "all" ] || [ "$DUMP_FOLDERS" = "tables" ]
then
    printf -- "$(date +'%T') Dumping tables for $DB to $DUMP_DIR/$DB/tables/\n"
    for TABLE in $($MYSQL -e "select TABLE_NAME from information_schema.tables where TABLE_SCHEMA = '$DB' AND TABLE_TYPE = 'BASE TABLE'" | egrep -v 'TABLE_NAME'); do
        FILE="$DUMP_DIR/$DB/tables/${TABLE}${OUTPUT_EXT}"
        echo "Dumping $DB.$TABLE to $FILE"
        $MYSQLDUMP --skip-add-locks --skip-disable-keys --skip-set-charset --lock-tables=false --single-transaction --no-data --triggers --skip-dump-date --skip-comments $TABLE | grep -v '/\*!' | sed 's/ AUTO_INCREMENT=[0-9]*//g' | $GZIP >$FILE
    done

    if [ "$TABLE" = "" ]; then
        echo "No tables found in db: $DB"
    fi
fi

# ----------
# Dump views
# ----------
if [ "$DUMP_FOLDERS" = "all" ] || [ "$DUMP_FOLDERS" = "views" ]
then
    printf -- "$(date +'%T') Dumping views for $DB to $DUMP_DIR/$DB/views/\n"
    TMPFILE=proc.tmp
    for TABLE in $($MYSQL -e "select TABLE_NAME from information_schema.tables where TABLE_SCHEMA = '$DB' AND TABLE_TYPE = 'VIEW'" | egrep -v 'TABLE_NAME'); do
        FILE="$DUMP_DIR/$DB/views/$TABLE.sql"
        # echo "Dumping $DB.$TABLE to $FILE"
        $MYSQLDUMP --skip-add-locks --skip-disable-keys --skip-set-charset --lock-tables=false --single-transaction --no-data --triggers $TABLE | $GZIP >$FILE

        #
        # Remove Top 16 Lines
        #
        LINECOUNT=`wc -l <${FILE}`
        ((LINECOUNT -= 16))
        tail -${LINECOUNT} <${FILE} >${TMPFILE}

        #
        # Remove Bottom 9 Lines
        #
        LINECOUNT=`wc -l <${TMPFILE}`
        ((LINECOUNT -= 9))
        head -${LINECOUNT} <${TMPFILE} | $GZIP >$FILE
    done
    rm -f ${TMPFILE}

    if [ "$TABLE" = "" ]; then
        echo "No views found in db: $DB"
    fi
fi

# ----------
# Dump stored procs
# ----------
if [ "$DUMP_FOLDERS" = "all" ] || [ "$DUMP_FOLDERS" = "procs" ]
then
    printf -- "$(date +'%T') Dumping stored procedures for $DB to $DUMP_DIR/$DB/procs/\n"
    TMPFILE=proc.tmp
    TMPFILE2=proc2.tmp
    for PROC in $($MYSQL -e "select Name from mysql.proc where db='${DB}' ORDER BY Name" | egrep -v 'Name'); do

        SQLSTMT="SELECT type FROM mysql.proc WHERE db='${DB}' AND name='$PROC'"
        PROC_TYPE=`$MYSQL -ANe "$SQLSTMT" | awk '{print $1}'`

        FILE="$DUMP_DIR/$DB/procs/$PROC.sql"

        SQLSTMT="SHOW CREATE ${PROC_TYPE} $PROC\G"
        $MYSQL -cANe "$SQLSTMT" >$FILE

        #
        # Remove Top 3 Lines
        #
        LINECOUNT=`wc -l <${FILE}`
        ((LINECOUNT -= 3))
        tail -${LINECOUNT} <${FILE} >${TMPFILE}

        #
        # Remove Bottom 3 Lines
        #
        LINECOUNT=`wc -l <${TMPFILE}`
        ((LINECOUNT -= 3))
        head -${LINECOUNT} <${TMPFILE} >${TMPFILE2}

        #
        # Add drop statement and delimiter at top, delimiter at bottom
        #
        (echo -e "DROP ${PROC_TYPE} IF EXISTS $DB.$PROC;\nDELIMITER //\n";
        cat ${TMPFILE2};
        echo -e "\n//\nDELIMITER ;\n") | $GZIP >$FILE
    done
    rm -f ${TMPFILE}
fi

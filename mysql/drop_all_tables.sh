#! /bin/bash
#---------------------------------
# Copyright 2010 ByWater Solutions
#---------------------------------
#
# This script will drop all tables from a MySQL database.  If you give it
# proper credentials, it will do it with no further prompting.
#
# USE WITH EXTREME CAUTION!
#

echo -n "Database name? "
read -e DB_NAME
echo -n "Username? "
read -e DB_USER
echo -n "Password? "
read -e DB_PASS
echo -n "Host? "
read -e HOST

MYSQL="mysql -u$DB_USER -h$HOST -p$DB_PASS $DB_NAME"
$MYSQL -BNe "show tables" |awk '{print "set foreign_key_checks=0; drop table `" $1 "`;"}' | $MYSQL
unset MYSQL

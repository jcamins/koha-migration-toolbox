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

echo -n "Username? "
read -e DB_USER
echo -n "Password? "
read -e DB_PASS
echo -n "Host? "
read -e HOST


echo -n "OLD database name? "
read -e DB_NAME
echo -n "NEW database name? "
read -e NEW_DB_NAME

MYSQL="mysql -u$DB_USER -h$HOST -p$DB_PASS $DB_NAME"
params=$($MYSQL -N -e "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE table_schema='$DB_NAME'")
 
for name in $params; do
      $MYSQL -e "RENAME TABLE $DB_NAME.$name to $NEW_DB_NAME.$name";
done;
unset MYSQL


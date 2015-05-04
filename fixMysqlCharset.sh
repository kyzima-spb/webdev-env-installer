#!/bin/bash


CONFIG_FILE=${1:-"/etc/mysql/my.cnf"}
CHARSET=${2:-"utf8"}
COLLATION=${3:-"utf8_general_ci"}


if [ ! -f $CONFIG_FILE ]; then
    exit 1
fi


found=$(grep -c default-character-set $CONFIG_FILE)

if [ $found -eq 0 ]; then
    sed -i "/\[client\]/ a default-character-set = $CHARSET" $CONFIG_FILE
    sed -i "/\[mysqldump\]/ a default-character-set = $CHARSET" $CONFIG_FILE
fi


found=$(grep -c character-set-server $CONFIG_FILE)

if [ $found -eq 0 ]; then
    mysqldCharset="init_connect = 'SET NAMES $CHARSET'\n"
    mysqldCharset+="character-set-server = $CHARSET\n"
    mysqldCharset+="collation-server = $COLLATION"

    sed -i "/\[mysqld\]/ a $mysqldCharset" $CONFIG_FILE
fi


exit 0
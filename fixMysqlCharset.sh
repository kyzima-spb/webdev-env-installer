#!/bin/bash


CONFIG_FILE=${1:-"/etc/mysql/my.cnf"}
CHARSET=${2:-"utf8mb4"}
COLLATION=${3:-"utf8mb4_general_ci"}


if [ ! -f $CONFIG_FILE ]; then
    exit 1
fi


props='default-character-set character-set-server collation-server init_connect'

for prop in $props; do
    pattern="^#?\s*?$prop\s*?=.*?$"
    sed -ri "/$pattern/d" $CONFIG_FILE
done


clientCharset="default-character-set = $CHARSET"

sed -i "/\[client\]/ a $clientCharset" $CONFIG_FILE
sed -i "/\[mysqldump\]/ a $clientCharset" $CONFIG_FILE


mysqldCharset="init_connect = 'SET NAMES $CHARSET'\n"
mysqldCharset+="character-set-server = $CHARSET\n"
mysqldCharset+="collation-server = $COLLATION"

sed -i "/\[mysqld\]/ a $mysqldCharset" $CONFIG_FILE


exit 0
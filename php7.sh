#!/bin/bash

installPHP7()
{
	if [ $DISTR_ID != "Debian" ]; then
		return 1
	fi

	local sourceList=${APT_SOURCE_DIR}dotdeb.list

	if ! [ -f $sourceList ]; then
		case $CODENAME in
            wheezy | jessie )
                local url=http://packages.dotdeb.org

		        if [ "$(getHttpStatusCode $url/dists/$CODENAME)" != '404' ]; then
		            echo deb $url $CODENAME all >> $sourceList
		            echo deb-src $url $CODENAME all >> $sourceList

		            wget -O - https://www.dotdeb.org/dotdeb.gpg | apt-key add -
		            apt-get update
		        fi
                ;;
        esac

		apt-get install -y php7.0-common php7.0-cli php7.0-fpm php7.0-readline \
                           php7.0-phpdbg \
                           php7.0-curl \
                           php7.0-intl \
                           php7.0-gmp \
                           php7.0-json \
                           php7.0-mcrypt \
                           php7.0-mysql php7.0-pgsql php7.0-sqlite3 \
                           php7.0-tidy php7.0-xsl
	fi
}

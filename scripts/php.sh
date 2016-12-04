#!/bin/bash

##
# Установка и настройка интерпретатора PHP
#
# Ubuntu ppa:ondrej/php
# PHP: 5.5, 5.6, 7.0
#
# Debian dotdeb.org + testing
# PHP: 5.6, 7.0
##

php_update_source_list()
{
    if [ $DISTR_ID == "Ubuntu" ]; then
        add-apt-repository ppa:ondrej/php -y
        apt-get update
        return
    fi

    if [ $DISTR_ID != "Debian" ]; then
        return
    fi

    local codenames="wheezy jessie"
    local sourceList=${APT_SOURCE_DIR}dotdeb.list

    if ! in_list $codenames $CODENAME; then
        return
    fi

    if ! [ -f $sourceList ]; then
        local url=http://packages.dotdeb.org

        if [ "$(getHttpStatusCode $url/dists/$CODENAME)" != '404' ]; then
            echo deb $url $CODENAME all >> $sourceList
            echo deb-src $url $CODENAME all >> $sourceList

            wget -O - https://www.dotdeb.org/dotdeb.gpg | apt-key add -
            apt-get update
        fi
    fi
}

php_install()
{
    if ! commandExists "php"; then
        php_update_source_list

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


    local scriptPath=$(dirname "$0")
    local F
    local installationPath=$(php --ini | grep "Configuration File (php.ini) Path:" | rev | cut -f1 -d \ | rev)
    installationPath=$(dirname "$installationPath")

    for F in $(find $installationPath -type f -name php.ini); do
        local pattern
        local replacement

        pattern='^;?\s*?cgi\.fix_pathinfo\s*?=.*?$'
        replacement='cgi.fix_pathinfo = 0'
        sed -ri "s/$pattern/$replacement/" $F

        pattern='^;?\s*?date\.timezone\s*?=.*?$'
        replacement='date.timezone = "Europe\/Moscow"'
        sed -ri "s/$pattern/$replacement/" $F
    done

    
    if [ ! -f "/var/log/php-fpm" ]; then
        mkdir -p /var/log/php-fpm
    fi


    local poolsPath=$installationPath/fpm/pool.d
    local poolName

    for F in $(find $scriptPath/configs/php-fpm -type f -name *.conf); do
        poolName=$(basename "$F" .conf)

        if [ ! -f "$poolsPath/$poolName.conf" ]; then
            cp $F $poolsPath
        fi
    done


    if [ ! -f /usr/local/bin/composer ]; then
        curl -sS https://getcomposer.org/installer | php
        mv composer.phar /usr/local/bin/composer
    fi
}







setupPHP()
{
    local scriptPath=$(dirname "$0")
    local installationPath=${1:-"/etc/php5"}
    local F
    

    if ! commandExists "php"; then
        distInfo

        if [ $DISTR_ID = "Ubuntu" ]; then
            add-apt-repository ppa:ondrej/php5-5.6 -y
            apt-get update
        fi
        
        apt-get install -y php5-common php5-cli php5-fpm php5-readline \
                            php5-xdebug php5-phpdbg \
                            php5-curl \
                            php5-intl \
                            php5-gmp \
                            php5-json \
                            php5-mcrypt \
                            php5-mysql php5-pgsql php5-sqlite php5-mongo \
                            php5-tidy php5-xsl
    fi
    

    for F in $(find $installationPath -type f -name php.ini); do
        local pattern
        local replacement

        pattern='^;?\s*?cgi\.fix_pathinfo\s*?=.*?$'
        replacement='cgi.fix_pathinfo = 0'
        sed -ri "s/$pattern/$replacement/" $F

        pattern='^;?\s*?date\.timezone\s*?=.*?$'
        replacement='date.timezone = "Europe\/Moscow"'
        sed -ri "s/$pattern/$replacement/" $F
    done


    if [ ! -f "/var/log/php-fpm" ]; then
        mkdir -p /var/log/php-fpm
    fi


    local poolsPath=$installationPath/fpm/pool.d
    local poolName

    for F in $(find $scriptPath/configs/php-fpm -type f -name *.conf); do
        poolName=$(basename "$F" .conf)

        if [ ! -f "$poolsPath/$poolName.conf" ]; then
            cp $F $poolsPath
        fi
    done


    if [ ! -f /usr/local/bin/composer ]; then
        curl -sS https://getcomposer.org/installer | php
        mv composer.phar /usr/local/bin/composer
    fi
}
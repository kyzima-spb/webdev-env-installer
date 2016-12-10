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


##
# Возвращает название команды для запуска PHP.
##
php_get_cmd()
{
    local version=${1:-"7"}
    echo $(compgen -c | egrep ^php$version[\.0-9]*$)
}


##
# Возвращает путь к директории, где установлен PHP.
# Принимает один не обязательный аргумент version: 5 или 7.
# По-умолчанию ищет версию 7.
##
php_get_installation_path()
{
    local version=${1:-"7"}
    local cmd=$(php_get_cmd $version)

    if [ "$cmd" == "" ]; then
        return
    fi

    local installationPath=$($cmd --ini | grep "Configuration File (php.ini) Path:" | rev | cut -f1 -d \ | rev)
    
    echo $(dirname "$installationPath")
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
    local installationPath=$(php_get_installation_path "7")

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


php_create_pool()
{
    if [ $# -lt 2 ]; then
        return
    fi

    local version=$1
    local user=$2

    if [ "$version" != "5" ] && [ "$version" != "7" ] ; then
        return
    fi

    local scriptPath=$(dirname "$0")
    local installationPath=$(php_get_installation_path $version)

    if [ "$installationPath" == "" ]; then
        return
    fi

    local cmd=$(php_get_cmd $version)
    cmd="$cmd-fpm"

    if [ -d "$installationPath/fpm" ]; then
        if [ ! -f "$installationPath/fpm/pool.d/$username.conf" ]; then
            $scriptPath/createFPMPool.sh $user > $installationPath/fpm/pool.d/$user.conf
        fi

        if [ ! -f "/tmp/$cmd/$user" ]; then
            mkdir -p /tmp/$cmd/$user
            chown $user:$user /tmp/$cmd/$user
        fi

        if [ ! -f "/var/log/php-fpm" ]; then
            mkdir -p "/var/log/php-fpm"
        fi

        service "$cmd" restart
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
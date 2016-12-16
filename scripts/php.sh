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


##
# Устанавливает PHP7
##
php_install()
{
    local cmd=$(php_get_cmd "7")

    if [[ -z $cmd ]]; then
        php_update_source_list
        php_find_and_install "7.0"
        php_fix_config_files "7"
        php_composer_install
    fi
}


##
# Устанавливает PHP5
##
php_5_install()
{
    local cmd=$(php_get_cmd "5")

    if [ "$cmd" == "" ]; then
        php_update_source_list
        php_find_and_install "5 5.6 5.5 5.4"
        php_fix_config_files "5"
        php_composer_install
    fi
}


##
# Устанавливает Composer
##
php_composer_install()
{
    if [ ! -f /usr/local/bin/composer ]; then
        curl -sS https://getcomposer.org/installer | php
        mv composer.phar /usr/local/bin/composer
    fi
}


##
# Исправляет все конфигурационные php-файлы для указанной версии
##
php_fix_config_files()
{
    local version=${1:-""}

    while [ "$version" != "5" ] && [ "$version" != "7" ]; do
        read -r -p "Enter PHP version [5,7]: " version
    done
        
    local scriptPath=$(dirname "$0")
    local F
    local installationPath=$(php_get_installation_path "$version")

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

    local pools_path=$installationPath/fpm/pool.d

    declare -A context=(
        ["name"]="prod"
        ["version"]=$version
        ["log_errors"]="on"
        ["display_errors"]="off"
    )
    render "$scriptPath/configs/php-fpm-pool.conf" "$(declare -p context)" "$pools_path/prod.conf"

    declare -A context=(
        ["name"]="dev"
        ["version"]=$version
        ["log_errors"]="off"
        ["display_errors"]="on"
    )
    render "$scriptPath/configs/php-fpm-pool.conf" "$(declare -p context)" "$pools_path/dev.conf"
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
            $scriptPath/createFPMPool.sh -n $user -v $version > $installationPath/fpm/pool.d/$user.conf
        fi

        service "$cmd" restart
    fi
}


##
# Выполняет поиск указанной версии PHP в репозитории и выполняет устанавку
##
php_find_and_install()
{
    local version
    local result
    local pkg
    local cmd="apt-get install -y"

    for version in $1; do
        result=$(apt-cache search php${version} | egrep ^php${version}-)

        if [[ ! -z $result ]]; then
            for pkg in common cli fpm readline xdebug phpdbg curl intl gmp json mcrypt mysql pgsql sqlite mongo tidy xsl; do
                cmd+=" $(echo $result | grep -o php${version}-${pkg})"
            done

            eval "$cmd"

            break
        fi
    done
}
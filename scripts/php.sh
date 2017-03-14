#!/bin/bash

##
# Установка и настройка интерпретатора PHP
#
# Ubuntu ppa:ondrej/php
# PHP: 5.5, 5.6, 7.0
#
# 
# Debian Wheezy -> dotdeb.org
# PHP: 5.6, 7.0
# 
# Debian Jessie, Stretch -> sury.org
# PHP: 5.6, 7.0, 7.1
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

    local codenames="wheezy jessie stretch"
    
    if ! in_list $codenames $CODENAME; then
        return
    fi
    
    if [ $CODENAME == "wheezy" ]; then
        local sourceList=${APT_SOURCE_DIR}dotdeb.list
        local url=http://packages.dotdeb.org
        local key_url=https://www.dotdeb.org/dotdeb.gpg
    else
        local sourceList=${APT_SOURCE_DIR}sury-php.list
        local url=https://packages.sury.org/php/
        local key_url=https://packages.sury.org/php/apt.gpg
        
        apt-get install apt-transport-https lsb-release ca-certificates
    fi

    if ! [ -f $sourceList ]; then
        if [ "$(getHttpStatusCode $url/dists/$CODENAME)" != '404' ]; then
            echo deb $url $CODENAME main >> $sourceList
            echo deb-src $url $CODENAME main >> $sourceList

            wget -O - $key_url | apt-key add -
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
# Возвращает название PHP-FPM сервиса.
##
php_get_service_name()
{
    local cmd=$(php_get_cmd "$1")
    local service_name

    if [[ -z $cmd ]]; then
        return
    fi

    service_name="$cmd-fpm"
        
    if service_exists $service_name; then
        echo $service_name
    fi
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
        
        if php_find_and_install "7.1 7.0"; then
            php_fix_config_files "7"
            php_composer_install
        fi
    fi
}


##
# Устанавливает PHP5
##
php_5_install()
{
    local cmd=$(php_get_cmd "5")

    if [[ -z $cmd ]]; then
        php_update_source_list
        
        if php_find_and_install "5 5.6 5.5 5.4"; then
            php_fix_config_files "5"
            php_composer_install
        fi
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

    declare -A context=(
        ["log_errors"]="on"
        ["display_errors"]="off"
    )
    php_create_pool "prod" $version "" "$(declare -p context)"

    declare -A context=(
        ["log_errors"]="off"
        ["display_errors"]="on"
    )
    php_create_pool "dev" $version "" "$(declare -p context)"
}


php_create_pool()
{
    local usage="
Usage:
 php_create_pool <pool_name> [<php_version>] [<user>] [<context>] [<pool_path>]
"

    if [ $# -lt 1 ]; then
        echo "$usage" >&2
        return 1
    fi

    local pool_name=${1:-""}
    local version=${2:-"7"}
    local user=${3:-"www-data"}
    local user_context=${4:-""}
    local pool_path=${5:-""}

    if [[ -z $pool_name ]]; then
        echo "Not passed pool filename!" >&2
        return 1
    fi

    if [ "$version" != "5" ] && [ "$version" != "7" ] ; then
        echo "Invalid PHP version! Use 5 or 7" >&2
        return 1
    fi

    local service_name=$(php_get_service_name "$version")

    if [[ -z $service_name ]]; then
        echo "PHP-FPM service not found." >&2
        return 1
    fi

    if [[ -z $pool_path ]]; then
        pool_path="$(php_get_installation_path "$version")/fpm/pool.d"
    fi

    make_dir $pool_path

    declare -A context=(
        ["group"]=$user
        ["access_log"]="/var/log/php-fpm/\\\$pool_access.log"
        ["slow_log"]="/var/log/php-fpm/\\\$pool_slow.log"
        ["error_log"]="/var/log/php-fpm/\\\$pool_error.log"
        ["log_errors"]="off"
        ["display_errors"]="on"
        ["memory_limit"]="256M"
        ["tmp_dir"]="/tmp/php-fpm/\\\$pool"
    )

    if [[ ! -z $user_context ]]; then
        eval "declare -A user_context="${user_context#*=}
        local key

        for key in "${!user_context[@]}"; do
            context[$key]=${user_context[$key]}
        done
    fi

    context["name"]=$pool_name
    context["version"]=$version
    context["user"]=$user

    make_dir $(dirname ${context[access_log]}) $user
    make_dir $(dirname ${context[slow_log]}) $user
    make_dir $(dirname ${context[error_log]}) $user
    make_dir $(dirname ${context[tmp_dir]}) $user

    render "$(dirname "$0")/configs/php-fpm-pool.conf" "$(declare -p context)" "$pool_path/$user.conf"

    service $service_name restart

    return 0
}


##
# Выполняет поиск указанной версии PHP в репозитории и выполняет устанавку.
# Возвращает 0, если установка прошла успешно и 1 в случаи ошибки.
##
php_find_and_install()
{
    local version
    local result
    local pkg
    local cmd="apt-get install"

    for version in $1; do
        result=$(apt-cache pkgnames php${version}-)

        if [[ ! -z $result ]]; then
            for pkg in common cli fpm readline xdebug phpdbg curl intl gmp json mcrypt mysql pgsql sqlite mongo tidy xsl
            do
                cmd+=" $(echo "$result" | egrep ^php${version}-${pkg}$)"
            done

            eval "$cmd"

            return 0
        fi
    done

    return 1
}

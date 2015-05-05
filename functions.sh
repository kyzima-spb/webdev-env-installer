#!/bin/bash


##
# Confirm action.
##
asksure()
{
    local msg=${1:-"Are you sure?"}
    local answer

    echo -n "$msg [Y/n]: "

    while read -r -n 1 -s answer; do
        case $answer in
            y|Y) echo; return 0;;
            n|N) echo; return 1;;
        esac
    done
}


##
# Возвращает 0, если команда найдена, или 1 - если не найдена.
##
commandExists()
{
    if [ "$(type -t $1)" = "" ]; then
        return 1
    else
        return 0
    fi
}


##
# Информация о дистрибутиве
##
distInfo()
{
    if [ -n "$DISTR_ID" ] && [ -n "$CODENAME" ]; then
        return
    fi

    DISTR_ID=$(lsb_release -is)
    CODENAME=$(lsb_release -cs)
    local note=""

    if [ "$DISTR_ID" = "LinuxMint" ]; then
        note=" (LinuxMint)"

        case $CODENAME in
            betsy )
                DISTR_ID="Debian"
                CODENAME="jessie"
                ;;
            rebecca | qiana)
                DISTR_ID="Ubuntu"
                CODENAME="trusty"
                ;;
            maya)
                DISTR_ID="Ubuntu"
                CODENAME="precise"
                ;;
        esac
    fi

    while [ 1 ]; do
        echo -e "The distributor's ID: $DISTR_ID$note"
        echo -e "The code name of the currently installed distribution: $CODENAME$note\n"

        if asksure "Is this ok?"; then
            break
        fi

        read -r -p "Enter the distributor's ID: " -e -i $DISTR_ID
        DISTR_ID=$REPLY

        read -r -p "Enter the code name of the currently installed distribution: " -e -i $CODENAME
        CODENAME=$REPLY
    done
}


##
# Возвращает 0, если пользователь существует, или 1 - если не существует.
##
userExists()
{
    if [ "$(grep -i "^$1:" /etc/passwd)" = "" ]; then
        return 1
    else
        return 0
    fi
}




##
# Добавляет пользователей в систему и инициализирует рабочее окружение
##
addUsers()
{
    while [ 1 ]; do
        if ! asksure "You want to create a new user?"; then
            break
        fi

        local username
        read -r -p "Enter username: " username

        adduser $username
        initUser $username
    done
}


##
# Изменить кодировку MySQL на UTF-8 по-умолчанию
##
fixMysqlCharset()
{
    if $(dirname "$0")/fixMysqlCharset.sh; then
        service mysql restart
    fi
}


##
# Инициализирует рабочее окружение пользователя
##
initUser()
{
    local scriptPath=$(dirname "$0")
    local username=${1:-""}


    if ! userExists $username; then
        return 1
    fi


    if [ ! -d /home/$username/www/public ]; then
        mkdir -p /home/$username/www/public
        chown -R $username:$username /home/$username/www
    fi


    if commandExists "php5-fpm"; then
        if [ ! -f /etc/php5/fpm/pool.d/$username.conf ]; then
            $scriptPath/createFPMPool.sh $username > /etc/php5/fpm/pool.d/$username.conf
        fi

        if [ ! -f "/tmp/php-fpm/$username" ]; then
            mkdir -p /tmp/php-fpm/$username
            chown $username:$username /tmp/php-fpm/$username
        fi

        service php5-fpm restart
    fi


    return 0
}


##
# Установить программное обеспечение необходимое при разработке
##
installDevelopementTools()
{
    apt-get install -y git dia \
                       mysql-workbench sqlitebrowser
}


##
# Установка стороннего софта из папки "soft"
##
installLocalSoft()
{
    local scriptPath=$(dirname "$0")
    local f

    for f in "$(ls $scriptPath/soft/*.deb)"; do
        dpkg -i $f
        
        if [ $? != 0 ]; then
            apt-get install -y -f
        fi
    done
}


##
# Установка системных пакетов
##
installSystemSoft()
{
    apt-get install -y vim curl flashplugin-nonfree arandr
}


##
# Установка и настройка легковесного локального DNS сервера
##
setupDNS()
{
    apt-get install -y resolvconf dnsmasq

    local configFile=${1:-'/etc/dnsmasq.conf'}

    if [ -f $configFile ]; then
        local found=$(grep -c address=/loc/127.0.0.1 $configFile)

        if [ $found -eq 0 ]; then
            sed -i '$ a \\naddress=/loc/127.0.0.1' $configFile
            sed -i '$ a listen-address=127.0.0.1' $configFile

            service dnsmasq restart
        fi
    fi
}


##
# Установка и настройка веб сервера NGINX
##
setupNginx()
{
    local scriptPath=$(dirname "$0")
    local installationPath=${1:-"/etc/nginx"}
    local sourceList=${APT_SOURCE_DIR}nginx-mainline.list


    if ! [ -f $sourceList ]; then
        distInfo

        case $CODENAME in
            testing | sid )
                local nginxCodename="jessie"
                ;;
            *)
                local nginxCodename=$CODENAME
                ;;
        esac

        echo deb http://nginx.org/packages/mainline/${DISTR_ID,,}/ $nginxCodename nginx >> $sourceList
        echo deb-src http://nginx.org/packages/mainline/${DISTR_ID,,}/ $nginxCodename nginx >> $sourceList

        wget -O - http://nginx.org/keys/nginx_signing.key | apt-key add -
        apt-get update
    fi


    if ! commandExists "nginx"; then
        apt-get install -y nginx
        cp $scriptPath/configs/nginx.conf $installationPath
    fi


    if [ ! -d $installationPath/sites-available ]; then
        mkdir -p /etc/nginx/sites-available
    fi

    if [ ! -d $installationPath/sites-enabled ]; then
        mkdir -p /etc/nginx/sites-available $installationPath/sites-enabled
    fi


    if [ ! -f $installationPath/sites-available/dev-zone-loc.conf ]; then
        cp $scriptPath/configs/nginx-dev-zone.conf $installationPath/sites-available/dev-zone-loc.conf
        ln -s $installationPath/sites-available/dev-zone-loc.conf $installationPath/sites-enabled/
        service nginx restart
    fi
}


##
# Установка и настройка сервера баз данных MySQL
##
setupMySQL()
{
    apt-get install -y mysql-server
    fixMysqlCharset
}


##
# Установка и настройка интерпретатора NodeJS
##
setupNodeJS()
{
    if ! commandExists "nodejs"; then
        apt-get install -y nodejs npm
        ln -s /usr/bin/nodejs /usr/bin/node # todo: проверить в Ubuntu
    fi
}


##
# Установка и настройка интерпретатора PHP
##
setupPHP()
{
    local scriptPath=$(dirname "$0")
    local installationPath=${1:-"/etc/php5"}

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
        local found=$(grep -c cgi.fix_pathinfo=1 $F)

        if [ $found -ne 0 ]; then
            sed -i "s/;\(cgi\.fix_pathinfo=\)1/\10/g" $F
        fi
    done


    if [ ! -f "/var/log/php-fpm" ]; then
        mkdir -p /var/log/php-fpm
    fi


    local poolsPath=$installationPath/fpm/pool.d
    local poolName
    local F

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


##
# Инициализирует окружение для существующих пользователей системы
##
updateUsers()
{
    while [ 1 ]; do
        if ! asksure "Do you want to initialize the user's work environment?"; then
            break
        fi

        local username
        read -r -p "Enter username: " username

        initUser $username
    done
}
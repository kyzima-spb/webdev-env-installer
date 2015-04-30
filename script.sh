#!/bin/bash


##
# Confirm action.
##
asksure()
{
    MSG=${1:-'Are you sure?'}

    echo -n "$MSG [Y/n]: "

    while read -r -n 1 -s ANSWER; do
        if [[ $ANSWER = [YyNn] ]]; then
            [[ $ANSWER = [Yy] ]] && retval=0
            [[ $ANSWER = [Nn] ]] && retval=1
            break
        fi
    done

    echo

    return $retval
}


##
# Возвращает 0, если команда найдена, или 1 - если не найдена.
##
commandExists()
{
    r=`type -t $1`

    if [ `type -t $1` ]; then
        return 0
    else
        return 1
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

    DISTR_ID=`lsb_release -is`
    CODENAME=`lsb_release -cs`
    NOTE=''

    if [ $DISTR_ID == 'LinuxMint' ]; then
        NOTE=' (LinuxMint)'

        case $CODENAME in
            betsy )
                DISTR_ID='Debian'
                CODENAME='jessie'
                ;;
            rebecca | qiana)
                DISTR_ID='Ubuntu'
                CODENAME='trusty'
                ;;
            maya)
                DISTR_ID='Ubuntu'
                CODENAME='precise'
                ;;
        esac
    fi

    while [ 1 ]; do
        echo -e "The distributor's ID: $DISTR_ID$NOTE"
        echo -e "The code name of the currently installed distribution: $CODENAME$NOTE\n"

        if asksure 'Is this ok?'; then
            break
        fi

        read -r -p "Enter the distributor's ID: " -e -i $DISTR_ID
        DISTR_ID=$REPLY

        read -r -p "Enter the code name of the currently installed distribution: " -e -i $CODENAME
        CODENAME=$REPLY
    done
}




##
# Добавляет пользователей в систему и создает необходимые файлы.
##
addUsers()
{
    while [ 1 ]; do
        if ! asksure 'You want to create a new user?'; then
            break
        fi

        read -r -p 'Enter username: '

        adduser $REPLY
        mkdir -p /home/$REPLY/www/public
        chown -R $REPLY:$REPLY /home/$REPLY/www

		if commandExists 'php'; then
			if [ ! -f /etc/php5/fpm/pool.d/$REPLY.conf ]; then
        		./createFPMPool.sh $REPLY > /etc/php5/fpm/pool.d/$REPLY.conf
        	fi

        	service php5-fpm restart
        fi
    done
}


##
# Установка локального софта
##
installLocalSoft()
{
    for f in `ls ./soft/*.deb`; do
        dpkg -i $f
    done
}


setCharsetUtf8ForMySQL()
{
    CONFIG_FILE=${1:-'/etc/mysql/my.cnf'}


    if [ ! -f $CONFIG_FILE ]; then
        return 2
    fi


    RETVAL=1

    FOUND=`grep -c default-character-set $CONFIG_FILE`

    if [ $FOUND -eq 0 ]; then
        sed -i '/\[client\]/ a default-character-set = utf8' $CONFIG_FILE
        sed -i '/\[mysqldump\]/ a default-character-set = utf8' $CONFIG_FILE
        RETVAL=0
    fi


    FOUND=`grep -c character-set-server $CONFIG_FILE`

    if [ $FOUND -eq 0 ]; then
        MYSQLD_CHARSET="init_connect = 'SET NAMES utf8'\n"
        MYSQLD_CHARSET+='character-set-server = utf8\n'
        MYSQLD_CHARSET+='collation-server = utf8_general_ci'

        sed -i "/\[mysqld\]/ a $MYSQLD_CHARSET" $CONFIG_FILE
        RETVAL=0
    fi

    return $RETVAL
}


##
# Установка и настройка легковестного локального DNS сервера
##
setupDNS()
{
    apt-get install -y dnsmasq

    CONFIG_FILE=${1:-'/etc/dnsmasq.conf'}

    if [ -f $CONFIG_FILE ]; then
        grep -q address=/loc/127.0.0.1 $CONFIG_FILE

        if [ $? -ne 0 ]; then
            sed -i '$ a \\naddress=/loc/127.0.0.1' $CONFIG_FILE
            sed -i '$ a \\nlisten-address=127.0.0.1' $CONFIG_FILE

            service dnsmasq restart
            service networking restart
        fi
    fi
}


##
# Установка и настройка веб сервера NGINX
##
setupNginx()
{
    INSTALLATION_PATH=${1:-'/etc/nginx'}
    SOURCE_LIST=${APT_SOURCE_DIR}nginx-mainline.list

    if ! [ -f $SOURCE_LIST ]; then
        distInfo

        case $CODENAME in
            testing | sid )
                NGINX_CODENAME='jessie'
                ;;
            *)
                NGINX_CODENAME=$CODENAME
                ;;
        esac

        echo deb http://nginx.org/packages/mainline/${DISTR_ID,,}/ $NGINX_CODENAME nginx >> $SOURCE_LIST
        echo deb-src http://nginx.org/packages/mainline/${DISTR_ID,,}/ $NGINX_CODENAME nginx >> $SOURCE_LIST

        wget -O - http://nginx.org/keys/nginx_signing.key | apt-key add -
        apt-get update
    fi

    if ! commandExists 'nginx'; then
        apt-get install -y nginx
        cp configs/nginx.conf /etc/nginx
    fi

    if [ ! -d $INSTALLATION_PATH/sites-available ]; then
        mkdir -p /etc/nginx/sites-available
    fi

    if [ ! -d $INSTALLATION_PATH/sites-enabled ]; then
        mkdir -p /etc/nginx/sites-available $INSTALLATION_PATH/sites-enabled
    fi

    if [ ! -f $INSTALLATION_PATH/sites-available/dev-zone-loc.conf ]; then
        cp configs/nginx-dev-zone.conf $INSTALLATION_PATH/sites-available/dev-zone-loc.conf
        ln -s $INSTALLATION_PATH/sites-available/dev-zone-loc.conf $INSTALLATION_PATH/sites-enabled/
        service nginx restart
    fi
}


##
# Установка и настройка сервера баз данных MySQL
##
setupMySQL()
{
    apt-get install -y mysql-server

    if setCharsetUtf8ForMySQL; then
        service mysql restart
    fi
}


##
# Установка и настройка интерпретатора NodeJS
##
setupNodeJS()
{
    if ! commandExists 'nodejs'; then
        apt-get install -y nodejs npm \
        ln -s /usr/bin/nodejs /usr/bin/node
    fi
}


##
# Установка и настройка интерпретатора PHP
##
setupPHP()
{
    INSTALLATION_PATH=${1:-'/etc/php5'}

    if ! commandExists 'php'; then
        distInfo

        if [ $DISTR_ID == 'Ubuntu' ]; then
            add-apt-repository ppa:ondrej/php5-5.6
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
    

    for F in `find $INSTALLATION_PATH -type f -name php.ini`; do
        FOUND=`grep -c cgi.fix_pathinfo=1 $F`

        if [ $FOUND -ne 0 ]; then
            echo 'Fix cgi.fix_pathinfo'
            sed -i 's/;\(cgi\.fix_pathinfo=\)1/\10/g' $F
        fi
    done


    if [ ! -f '/var/log/php-fpm' ]; then
        mkdir -p /var/log/php-fpm
    fi


    PATH_TO_POOLS=$INSTALLATION_PATH/fpm/pool.d

    if [ ! -f $PATH_TO_POOLS/prod.conf ]; then
        cp configs/php-fpm/prod.conf $PATH_TO_POOLS
    fi

    if [ ! -f $PATH_TO_POOLS/dev.conf ]; then
        cp configs/php-fpm/dev.conf $PATH_TO_POOLS
    fi


    if [ ! -f /usr/local/bin/composer ]; then
        curl -sS https://getcomposer.org/installer | php
        mv composer.phar /usr/local/bin/composer
    fi
}



main()
{
    APT_SOURCE_DIR='/etc/apt/sources.list.d/'

    if [ "$(whoami)" != 'root' ]; then
        echo $"You have no permission to run $0 as non-root user. Use sudo" >&2
        exit 1;
    fi

    distInfo

    apt-get update

    apt-get install -y vim curl flashplugin-nonfree arandr \
                    git dia \
                    mysql-workbench sqlitebrowser

    installLocalSoft

    setupNginx
    setupPHP
    setupMySQL
    setupNodeJS
    setupDNS
    addUsers

    exit 0
}


main
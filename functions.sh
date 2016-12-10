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
# Возвращает 1, если элемент есть в списке или 0 - если нет.
##
in_list()
{
    local i

    for i in $1; do
        if [ $i = $2 ]; then
            return 1
        fi
    done

    return 0
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
            sarah)
                DISTR_ID="Ubuntu"
                CODENAME="xenial"
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
# Получить HTTP код ответа сервера
##
getHttpStatusCode()
{
    curl --write-out %{http_code} --silent --output /dev/null $1
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
    apt-get install vim curl flashplugin-nonfree arandr zsh
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
# Установка и настройка сервера баз данных MySQL
##
setupMySQL()
{
    apt-get install -y mysql-server
    fixMysqlCharset
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
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

    if [ $http_proxy ]; then
        git config --global http.proxy $http_proxy
    else
        git config --global --unset http.proxy
    fi

    return 0
}
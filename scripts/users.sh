##
# Добавляет пользователей в систему и инициализирует рабочее окружение
##
user_create()
{
    while [ 1 ]; do
        if ! asksure "You want to create a new user?"; then
            break
        fi

        local username
        read -r -p "Enter username: " username

        adduser $username
        user_init_env $username
    done
}


##
# Возвращает 0, если пользователь существует, или 1 - если не существует.
##
user_exists()
{
    if [ "$(grep -i "^$1:" /etc/passwd)" = "" ]; then
        return 1
    else
        return 0
    fi
}


##
# Инициализирует рабочее окружение пользователя
##
user_init_env()
{
    local scriptPath=$(dirname "$0")
    local username=${1:-""}


    if ! user_exists $username; then
        return 1
    fi


    if [ ! -d /home/$username/www/public ]; then
        mkdir -p /home/$username/www/public
        chown -R $username:$username /home/$username/www
    fi

    local pv

    for pv in 2 5 7; do
        local php_cmd=$(php_get_cmd $pv)

        if [[ ! -z $php_cmd ]]; then
            declare -A context=(
                ["log_errors"]="off"
                ["display_errors"]="on"
            )
            php_create_pool "$username" "$pv" "$username" "$(declare -p context)"
        fi
    done

    if [ $http_proxy ]; then
        git config --global http.proxy $http_proxy
    else
        git config --global --unset http.proxy
    fi

    return 0
}


##
# Инициализирует окружение для существующих пользователей системы
##
user_update_env()
{
    while [ 1 ]; do
        if ! asksure "Do you want to initialize the user's work environment?"; then
            break
        fi

        local username
        read -r -p "Enter username: " username

        user_init_env $username
    done
}
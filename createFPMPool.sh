#!/bin/bash

show_help()
{
    echo "
Usage:
 ${0##*/} -n <pool_name> -u <user> -v <php_version>
 ${0##*/} -h

Options:
 -n pool name
 -u username. The default is the name of the pool
 -v PHP version used. Default 7
 -h display this help and exit
"
}


pool_name=""
user=""
version="7"


while getopts "hn:u:v:" arg; do
    case $arg in
        n) pool_name=${OPTARG};;
        u) user=${OPTARG};;
        v) version=${OPTARG};;
        h)
            show_help
            exit 0
            ;;
        *)
            show_help >&2
            exit 1
            ;;
    esac
done


if [ "$pool_name" = "" ]; then
    echo "Not passed pool name!" >&2
    exit 1
fi


if [ "$user" = "" ]; then
    user=$pool_name
fi

if [ "$version" != "5" ] && [ "$version" != "7" ] ; then
    echo "Invalid PHP version! Use 5 or 7" >&2
    exit 1
fi


name="php$version-fpm"
log_path="/var/log/$name"
tmp_path="/tmp/$name/$pool_name"


if [ ! -f "$log_path" ]; then
    mkdir -p "$log_path"
fi


if [ ! -f "$tmp_path" ]; then
    mkdir -p "$tmp_path"
    chown $user:$user $tmp_path
fi


if [ "$user" = "$pool_name" ]; then
    user="\$pool"
fi


echo "[$pool_name]
    user  = $user
    group = $user

    listen       = /var/run/${name}_$user.sock
    listen.owner = $user
    listen.group = $user
    listen.mode  = 0666

    request_terminate_timeout = 2m

    pm                      = dynamic
    pm.max_children         = 15
    pm.start_servers        = 2
    pm.min_spare_servers    = 1
    pm.max_spare_servers    = 3
    pm.process_idle_timeout = 10s
    pm.max_requests         = 25

    access.log = ${log_path}/${user}_access.log
    slowlog = ${log_path}/${user}_slow.log
    request_slowlog_timeout = 5s

    php_admin_value[error_log]         = ${log_path}/${user}_error.log
    php_admin_value[memory_limit]      = 256M
    php_admin_value[upload_tmp_dir]    = /tmp
    php_admin_value[session.save_path] = /tmp

    php_admin_flag[log_errors]     = off
    php_admin_flag[display_errors] = on"


exit 0
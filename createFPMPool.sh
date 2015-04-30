#!/bin/bash


POOL_NAME=${1:-''}


if [ "$POOL_NAME" == "" ]; then
    echo "Not passed pool name!" >&2
    exit 1
fi

echo "[$POOL_NAME]
    user  = \$pool
    group = \$pool

    listen       = /var/run/php-fpm_\$pool.sock
    listen.owner = \$pool
    listen.group = \$pool
    listen.mode  = 0666

    request_terminate_timeout = 2m

    pm                      = dynamic
    pm.max_children         = 15
    pm.start_servers        = 2
    pm.min_spare_servers    = 1
    pm.max_spare_servers    = 3
    pm.process_idle_timeout = 10s
    pm.max_requests         = 25

    access.log = /var/log/php-fpm/\$pool_access.log
    slowlog = /var/log/php-fpm/\$pool_slow.log
    request_slowlog_timeout = 5s

    env[TMP]    = /tmp/php-fpm/\$pool
    env[TMPDIR] = /tmp/php-fpm/\$pool
    env[TEMP]   = /tmp/php-fpm/\$pool

    php_admin_value[error_log]         = /var/log/php-fpm/\$pool_error.log
    php_admin_value[memory_limit]      = 256M
    php_admin_value[upload_tmp_dir]    = /tmp/php-fpm/\$pool
    php_admin_value[session.save_path] = /tmp/php-fpm/\$pool

    php_admin_flag[log_errors]     = on
    php_admin_flag[display_errors] = off"

exit 0
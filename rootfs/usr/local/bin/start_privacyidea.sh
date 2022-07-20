#!/bin/bash
set -e

source /usr/local/bin/_privacyidea_common.sh

function main {
    echo ""
    echo "[PrivacyIDEA] Starting ${PrivacyIDEA}. To stop the container with CTRL-C, run this container with the option \"-it\"."
    echo ""

    generate_pi_config
    prestart_privacyidea
    exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
}

function generate_pi_config {

    if { [ "${DB_VENDOR}" = "mariadb" ] || [ "${DB_VENDOR}" = "mysql" ]; } then
        echo "Using $DB_VENDOR..."
        [ -z "$DB_HOST" ] && echo "DB_HOST should be defined" && return 1
        [ -z "$DB_USER" ] && echo "DB_USER should be defined" && return 1
        [ -z "$DB_PASSWORD" ] && echo "DB_PASSWORD should be defined" && return 1
        [ -z "$DB_NAME" ] && echo "DB_NAME should be defined" && return 1
        if [ -z "$DB_PORT" ]; then
            echo DB_PORT is not defined using default port
            export DB_PORT=3306
        fi
        export SQLALCHEMY_DATABASE_URI=pymysql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}
    elif { [ "${DB_VENDOR}" = "postgresql" ]; } then
        [ -z "$DB_HOST" ] && echo "DB_HOST should be defined" && return 1
        [ -z "$DB_USER" ] && echo "DB_USER should be defined" && return 1
        [ -z "$DB_PASSWORD" ] && echo "DB_PASSWORD should be defined" && return 1
        [ -z "$DB_NAME" ] && echo "DB_NAME should be defined" && return 1
        if [ -z "$DB_PORT" ]; then
            echo DB_PORT is not defined using default port
            export DB_PORT=5432
        fi
        export SQLALCHEMY_DATABASE_URI=postgresql+psycopg2://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}
    else
        echo "DB_VENDOR enviroment varaible is not set. Using default SQLite..."
        echo ""
        export SQLALCHEMY_DATABASE_URI=sqlite:////etc/privacyidea/data/privacyidea.db
    fi

    if [ ! -f /etc/privacyidea/pi.cfg ];
    then
        if [ -z "$SQLALCHEMY_DATABASE_URI" ];
        then
            echo "SQLALCHEMY_DATABASE_URI is undefieded"
        else
            envsubst < /opt/templates/pi-config.template > /etc/privacyidea/pi.cfg
        fi
    fi
}

function prestart_privacyidea {

    if [ -d "${PI_MOUNT_DIR}"/files ]
    then
        if [[ $(ls -A "${PI_MOUNT_DIR}"/files) ]]
        then
            echo "[privacyIDEA] Copying files from ${PI_MOUNT_DIR}/files:"
            echo ""

            tree --noreport "${PI_MOUNT_DIR}"/files

            echo ""
            echo "[privacyIDEA] ... into ${PI_HOME}."

            cp -r "${PI_MOUNT_DIR}"/files/* "${PI_HOME}"

            echo ""
            fi
    else
        echo "[privacyIDEA] The directory /mnt/privacyidea/files does not exist. Create the directory \$(pwd)/xyz123/files on the host operating system to create the directory ${PI_MOUNT_DIR}/files on the container. Files in ${PI_MOUNT_DIR}/files will be copied to ${PI_HOME} before privacyIDEA starts."
        echo ""
    fi

    if [ -d "${PI_MOUNT_DIR}"/scripts ]
    then
        execute_scripts "${PI_MOUNT_DIR}"/scripts
	else
        echo "[privacyIDEA] The directory /mnt/privacyidea/scripts does not exist. Create the directory \$(pwd)/xyz123/scripts on the host operating system to create the directory ${PI_MOUNT_DIR}/scripts on the container. Files in ${PI_MOUNT_DIR}/scripts will be executed, in alphabetical order, before privacyIDEA starts."
        echo ""
    fi

    if [ "${PI_SKIP_BOOTSTRAP}" = false ]; then
        ls -l /data
         ls -l /data/privacyidea
        if [ ! -f /etc/privacyidea/encfile ]; then
            pi-manage create_enckey
        fi
        if [ ! -d /etc/privacyidea/keys ]; then
            mkdir /etc/privacyidea/keys
        fi
        if [ ! -f /etc/privacyidea/keys/private.pem ]; then
            pi-manage create_audit_keys
        fi
        pi-manage createdb
        pi-manage db stamp head -d /opt/privacyidea/lib/privacyidea/migrations/
        if { [ "${PI_SKIP_BOOTSTRAP}" = false ] && [ -z ${PI_ADMIN_USER} ] && [ -z ${PI_ADMIN_PASSWORD} ]; } then
            echo "Create deafult admin user. Not recommented in production. Please set PI_ADMIN_USER and PI_ADMIN_PASSWORD in production enviroment."
            pi-manage admin add admin -p privacyidea
        else
            echo "Create admin user from definded enviroment variables."
            pi-manage admin add ${PI_ADMIN_USER} -p ${PI_ADMIN_PASSWORD}
        fi
    fi
}

main

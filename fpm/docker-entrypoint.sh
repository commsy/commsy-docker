#!/bin/bash
set -e

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

if [ "$1" == php-fpm ]; then
    if ! [ -e VERSION ]; then
        echo >&2 "CommSy not found in $PWD - copying now..."
        tar cf - --one-file-system -C /usr/src/commsy . | tar xf -
        echo >&2 "Complete! CommSy has been successfully copied to $PWD"
    fi

    envs=(
        COMMSY_DB_HOST
        COMMSY_DB_USER
        COMMSY_DB_PASSWORD
        COMMSY_DB_NAME
        COMMSY_HOST
        COMMSY_SCHEME
        COMMSY_MAIL_HOST
        COMMSY_MAIL_PORT
        COMMSY_MAIL_FROM
        COMMSY_LOCALE
        COMMSY_ELASTIC_HOST
        COMMSY_ELASTIC_PORT
    )

    haveConfig=
	for e in "${envs[@]}"; do
		file_env "$e"
		if [ -z "$haveConfig" ] && [ -n "${!e}" ]; then
			haveConfig=1
		fi
	done

	# only touch "parameters.yml" if we have environment-supplied configuration values
	if [ "$haveConfig" ]; then
	    echo >&2 "Setting configuration"

	    : "${COMMSY_DB_HOST:=commsy_db}"
		: "${COMMSY_DB_USER:=root}"
		: "${COMMSY_DB_PASSWORD:=}"
		: "${COMMSY_DB_NAME:=commsy}"

		: "${COMMSY_HOST:=example.org}"
		: "${COMMSY_SCHEME:=https}"

		: "${COMMSY_MAIL_HOST:=127.0.0.1}"
		: "${COMMSY_MAIL_PORT:=25}"
		: "${COMMSY_MAIL_FROM:=example@example.com}"

		: "${COMMSY_LOCALE:=en}"

		: "${COMMSY_ELASTIC_HOST:=localhost}"
		: "${COMMSY_ELASTIC_PORT:=9200}"

		if [ ! -e app/config/parameters.yml ]; then
            cp app/config/parameters.yml.dist app/config/parameters.yml
            chown www-data:www-data app/config/parameters.yml
        fi

        if [ ! -e legacy/etc/cs_config.php ]; then
            cp legacy/etc/cs_config.php-dist legacy/etc/cs_config.php
            chown www-data:www-data legacy/etc/cs_config.php
        fi

        set_config() {
			key="$1"
			value="$2"
#			var_type="${3:-string}"
#			start="(['\"])$(sed_escape_lhs "$key")\2\s*,"
#			end="\);"
#			if [ "${key:0:1}" = '$' ]; then
#				start="^(\s*)$(sed_escape_lhs "$key")\s*="
#				end=";"
#			fi
			sed -ri -e "s/$key:.*/$key: $value/" app/config/parameters.yml
		}

        # see http://stackoverflow.com/a/2705678/433558
#		sed_escape_lhs() {
#			echo "$@" | sed -e 's/[]\/$*.^|[]/\\&/g'
#		}
#		sed_escape_rhs() {
#			echo "$@" | sed -e 's/[\/&]/\\&/g'
#		}
#		php_escape() {
#			php -r 'var_export(('$2') $argv[1]);' -- "$1"
#		}
#		set_config() {
#			key="$1"
#			value="$2"
#			var_type="${3:-string}"
#			start="(['\"])$(sed_escape_lhs "$key")\2\s*,"
#			end="\);"
#			if [ "${key:0:1}" = '$' ]; then
#				start="^(\s*)$(sed_escape_lhs "$key")\s*="
#				end=";"
#			fi
#			sed -ri -e "s/($start\s*).*($end)$/\1$(sed_escape_rhs "$(php_escape "$value" "$var_type")")\3/" app/config/parameters.yml
#		}
#
		set_config 'database_host' "$COMMSY_DB_HOST"
		set_config 'database_user' "$COMMSY_DB_USER"
		set_config 'database_password' "$COMMSY_DB_PASSWORD"
		set_config 'database_name' "$COMMSY_DB_NAME"

		set_config 'router.request_context.host' "$COMMSY_HOST"
		set_config 'router.request_context.scheme' "$COMMSY_SCHEME"

		set_config 'mailer_host' "$COMMSY_MAIL_HOST"
		set_config 'mailer_port' "$COMMSY_MAIL_PORT"
		set_config 'email.from' "$COMMSY_MAIL_FROM"

		set_config 'locale' "$COMMSY_LOCALE"

		set_config 'elastic_host' "$COMMSY_ELASTIC_HOST"
		set_config 'elastic_port' "$COMMSY_ELASTIC_PORT"
	fi

	# now that we're definitely done writing configuration, let's clear out the relevant environment variables (so that stray "phpinfo()" calls don't leak secrets from our code)
	for e in "${envs[@]}"; do
		unset "$e"
	done

	sudo -H -u www-data bash -c 'php composer.phar install --no-interaction --optimize-autoloader'
    sudo -H -u www-data bash -c 'php bin/console cache:clear --env=prod --no-debug'
#    sudo -H -u www-data bash -c 'php bin/console doctrine:fixtures:load --append'
    sudo -H -u www-data bash -c 'php bin/console --no-interaction doctrine:migrations:migrate'
    sudo -H -u www-data bash -c 'php bin/console fos:elastica:populate'
    sudo -H -u www-data bash -c 'npm install'
    sudo -H -u www-data bash -c 'bower --config.analytics=false install'
    sudo -H -u www-data bash -c 'gulp --prod'
fi

exec "$@"
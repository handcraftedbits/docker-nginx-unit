#!/bin/bash

units_dir=/opt/container/shared/etc/nginx/host/units

function checkCommonRequiredVariables () {
     requiredVariable NGINX_UNIT_HOSTS
     optionalVariable NGINX_URL_PREFIX "/"
}

function copyUnitConf () {
     local unit_conf=${units_dir}/${NGINX_UNIT_HOSTS}/${1}-`hostname`.conf

     if [ ! -d ${units_dir}/${NGINX_UNIT_HOSTS} ]
     then
          mkdir -p ${units_dir}/${NGINX_UNIT_HOSTS}
     fi

     # Add randomness to the unit configuration file name in case two of the same units are used at the same time.

     cp /opt/container/template/${1}.conf.template ${unit_conf}

     # Perform substitutions for variables common to all units.

     fileSubstitute ${unit_conf} NGINX_PROXY_HOST `hostname`
     fileSubstitute ${unit_conf} NGINX_URL_PREFIX `normalizeSlashes "/${NGINX_URL_PREFIX}/"`
     fileSubstitute ${unit_conf} unit_conf ${unit_conf}

     # Perform appropriate substitutions if there's a user-provided set of directives to use.

     if [ -f /etc/nginx/extra/unit.extra.conf ]
     then
          cp /etc/nginx/extra/unit.extra.conf ${unit_conf}.extra

          sed -i "s/#include/include/g" ${unit_conf}
     fi

     echo ${unit_conf}
}

function fileSubstitute () {
     sed -i "s%\${"${2}"}%"${3}"%g" ${1}
}

function fixDoubleSlash () {
     echo ${1} | sed "s%//%/%g"
}

function logError () {
     echo "[error] ${1}"
}

function logInfo () {
     echo "[info] ${1}"
}

function logUrlPrefix () {
     logInfo "using URL prefix '"`normalizeSlashes "/${NGINX_URL_PREFIX}/" | sed "s%/$%%g"`"' for ${1}"
}

function logWarning () {
     echo "[warning] ${1}"
}

function normalizeSlashes () {
     local before=${1}
     local after=`fixDoubleSlash ${1}`

     while [ "$after" != "$before" ]
     do
          before=$after
          after=`fixDoubleSlash $before`
     done

     echo $after | sed "s/ //g"
}

# Used in instances where a value of "/" needs to be replaced with "".

function normalizeSlashesSingleSlashToEmpty () {
     local normalized=`normalizeSlashes ${1}`

     if [ "${normalized}" == "/" ]
     then
          echo $normalized | sed "s%/%%g"
     else
          echo $normalized
     fi
}

function notifyUnitLaunched () {
     mkdir -p ${units_dir}/__launched__

     touch ${units_dir}/__launched__/`hostname`
}

function notifyUnitStarted () {
     nc -l 1234 > /dev/null
}

function optionalVariable () {
     if [ -z "${!1}" ]
     then
          logWarning "\${${1}} is not set; using default value '${2}'"

          eval ${1}=${2}
     fi
}

function requiredVariable () {
     if [ -z "${!1}" ]
     then
          logError "\${${1}} is not set"

          exit 1
     fi
}
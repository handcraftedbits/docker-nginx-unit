#!/bin/bash

units_dir=/opt/container/shared/etc/nginx/host/units

function checkCommonRequiredVariables () {
     requiredVariable NGINX_UNIT_HOSTS
     optionalVariable NGINX_URL_PREFIX "/"
}

function copyUnitConf () {
     local filename=${units_dir}/${NGINX_UNIT_HOSTS}/${1}-`hostname`.conf

     if [ ! -d ${units_dir}/${NGINX_UNIT_HOSTS} ]
     then
          mkdir -p ${units_dir}/${NGINX_UNIT_HOSTS}
     fi

     # Add randomness to the unit configuration file name in case two of the same units are used at the same time.

     cp /opt/container/template/${1}.conf.template ${filename}

     # Perform substitutions for variables common to all units.

     fileSubstitute ${filename} NGINX_PROXY_HOST `hostname`
     fileSubstitute ${filename} NGINX_URL_PREFIX `normalizeSlashes "/${NGINX_URL_PREFIX}/"`
     fileSubstitute ${filename} unit_conf ${filename}

     # Perform appropriate substitutions if there's a user-provided set of directives to use.

     if [ -f /etc/nginx/extra/unit.extra.conf ]
     then
          cp /etc/nginx/extra/unit.extra.conf ${filename}.extra

          sed -i "s/#include/include/g" ${filename}
     fi

     echo ${filename}
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

function onProcessStopped () {
     rm -f ${2}

     kill -TERM ${1}

     wait ${1}
}

function optionalVariable () {
     if [ -z "${!1}" ]
     then
          logWarning "\${${1}} is not set; using default value '${2}'"

          eval ${1}=${2}
     fi
}

function randomInt () {
     od -vAn -N4 -tu4 < /dev/urandom | tr -d "[[:space:]]"
}

function requiredVariable () {
     if [ -z "${!1}" ]
     then
          logError "\${${1}} is not set"

          exit 1
     fi
}

# Start the process and get the PID so we can trap the stop/kill signals and clean up before actually killing the
# underlying process.

startProcessWithTrap () {
     func=${1}
     unitFile=${2}

     shift
     shift

     $@ &

     pid=$!

     trap "${func} ${pid} ${unitFile}" INT KILL TERM

     wait ${pid}
}

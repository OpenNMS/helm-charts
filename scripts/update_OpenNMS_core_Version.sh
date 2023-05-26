#!/bin/bash

export new_version=''

if [ $# -eq 0 ]; then
 new_version='latest'
else
 new_version=$1
fi


export root_path=""
if [ ! -d "examples" ]; then
 if [ -d "../examples" ]; then
  root_path="../"
 fi
fi


printf "\033[36m%s\033[0m:\033[0m\033[33m %s\n\033[0m" "Step 1" "Modifying opennms/values.yaml"
sed -rie 's/(opennmsVersion: ?).*/\1'$new_version'/g' "${root_path}opennms/values.yaml"
if [ -f "${root_path}opennms/values.yamle" ]; then
 rm ${root_path}opennms/values.yamle
fi
echo ""

printf "\033[36m%s\033[0m:\033[0m\033[33m %s\n\033[0m" "Step 2" "Modifying opennms/Chart.yaml"
sed -rie 's/(appVersion: ?).*/\1'$new_version'/g' "${root_path}opennms/Chart.yaml"
if [ -f "${root_path}opennms/Chart.yamle" ]; then
 rm ${root_path}opennms/Chart.yamle
fi
echo ""


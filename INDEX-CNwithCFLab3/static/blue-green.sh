#!/bin/bash
#
# This product includes software originally developed by IBM Corporation.
#
#
# Copyright IBM Corp. 2018
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# **********************************USAGE***************************************
# This script will will do a blue/green deployment of an app to Cloud Foundry. #
# It assumes you are already logged in, if not make sure you run `cf login`    #
# before executing this script.                                                #
#                                                                              #
# This script can do the following things                                       #
# 1. Push the application                                                      #
# 2. Bind Services                                                             #
# 3. Set Environment Variables                                                 #
# 4. Map Routes                                                                #
# 5. Start the application                                                     #
#                                                                              #
# If a version of the application already exists in the org and space being    #
# deployed to this script will deploy the new application under the name       #
# <appName>-new.  The routes mapped to the existing application will be mapped #
# to the new version.  Then the old version of the application will be deleted #
# and the new version will be renamed to <appName>.                            #
#                                                                              #
# The scripts depends on a couple of environment variables being set.          #
# 1. CF_APP - This environment variable is set by default in IBM DevOPs        #
#    Services                                                                  #
# 2. ENV_VARS - Environment variables to be set.  The value should take the    #
#    form NAME1:value1,NAME2:value2                                            #
# 3. SERVICES - Services that should be bound to the application. The value    #
#    should take the form servicename1,servicename2                            #
# 4. ROUTES - Routes that should be mapped to the app.  The value should       #
#    take the form host1:domain1,host2:domain2,domain3                         #
# 5. CF_PUSH_ARGS - a string of arguments to use when calling `cf push         #
#    For example, pushing a specific artifact or setting the memory.           #
# ******************************************************************************


COMMAND="cf apps | grep -w --quiet ${CF_APP}"

if eval $COMMAND; then
  export EXISTS=true
  export APP_NAME="${CF_APP}-new"
else
  export EXISTS=false
  export APP_NAME="${CF_APP}"
fi

echo "Pushing application"

cf push ${APP_NAME} ${CF_PUSH_ARGS} --no-start

echo "Done pushing application"

echo "Setting environment variables"

IFS=',' read -a envvarsarray <<< "$ENV_VARS"
for element in "${envvarsarray[@]}"
do
  IFS=':' read -a envvar <<< "$element"
  cf set-env $APP_NAME ${envvar[0]} ${envvar[1]}
done

echo "Binding services"

IFS=',' read -a servicesarray <<< "$SERVICES"
for element in "${servicesarray[@]}"
do
  cf bind-service $APP_NAME $element
done

echo "Done mapping services"

echo "Starting application"

cf start $APP_NAME

echo "Done starting application"

echo "Map routes to new instance"

IFS=',' read -a routesarray <<< "$ROUTES"
for element in "${routesarray[@]}"
do
  if [[ $element == *":"* ]]; then
    IFS=':' read -a route <<< "$element"
    cf map-route $APP_NAME ${route[1]} -n ${route[0]}
  else
    cf map-route $APP_NAME $element
  fi
done

echo "Done mapping routes"

echo "Cleaning up prior application if it exists and any orphan routes"

if $EXISTS; then
  cf delete -f ${CF_APP}
  cf rename $APP_NAME ${CF_APP}
  cf delete-orphaned-routes -f
else
  echo "No cleanup needed, app did not exist"
fi

echo "Done cleaning up the old application"

# view logs
#cf logs "${CF_APP}" --recent

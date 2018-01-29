#!/bin/bash
#
#
# Author: Mike Kurtis - mkurtis@mesosphere.com
#
# Description:
#
#  - Takes a single MoM (Marathon on Marathon) json file as input and produces a 
#      modified MoM json file which will listen to JMX traffic (enabling performance profiling)
#
# Usage:
#
#  ./add_jmx_config_to_mom_json.sh <jsonfile>


#
# Check args;
#

if [ $# -lt 1 ] ; then
    echo "Usage: $0 <user-marathon.JSON>"
    exit 1
fi



#
# Check input file is readable;
#

MOM_JSON_FILE=$1
if [ ! -r "$MOM_JSON_FILE" ] ; then
    echo "ERROR: Couldn't read Mom file $MOM_JSON_FILE" 
    exit 2
fi



#
# Check that this json file doesn't already have JAVA_OPTS_PRE, if so exit!
#

if [ $( egrep -c 'JAVA_OPTS_PRE' "${MOM_JSON_FILE}" ) -gt 0 ];then
    echo "ERROR: found JAVA_OPTS_PRE already in 'cmd' did you already run me against ${MOM_JSON_FILE} ??"
    exit 11
fi



#
# Check that jq is available;
#

if [ ! $( jq --version ) ];then 
   echo 'ERROR: jq not found.  Consider installing from https://stedolan.github.io/jq/'
   exit 14
fi




################################################################################
# Pull out old stuff from json file (e.g. if it were pulled from a prod system #
################################################################################

cat "${MOM_JSON_FILE}" | jq 'del(.tasks, .tasksHealthy, .tasksRunning, .tasksStaged, .tasksUnhealthy, .version, .versionInfo)' > "${MOM_JSON_FILE}.interim"




#######################################
# Modify the json file's .cmd section #
#######################################


#
# Pull 'cmd' out of json file;
#

CMD=$( cat "$MOM_JSON_FILE" | jq -er '.cmd')




#
#
# Use 'sed' to modify the 'cmd', (we will later use 'jq' to swap this new cmd in);
#
JSTUFF_TO_ADD='export JAVA_OPTS=\"$JAVA_OPTS_PRE -Djava.rmi.server.hostname=$HOST -Dcom.sun.management.jmxremote.port=$PORT_JMX -Dcom.sun.management.jmxremote.rmi.port=$PORT_JMX \"'
# Note, we are adding (back) the $PORT1, and have to \ protect the '$', and also the '&&' plus the JSTUFF_TO_ADD;
NEWCMD=$( echo ${CMD} | sed -e  "/["]cmd["]/s/LIBPROCESS_PORT[=][$]PORT1/LIBPROCESS_PORT=\$PORT1 \&\& $JSTUFF_TO_ADD/" )


# 
# Use jq to replace the 'cmd' in the json file.
# The bash "${NEWCMD}" variable is copied to the jq "$JQNEWCMD" var.  Replace the old value of '.cmd' with $JQNEWCMD;
#

cat "${MOM_JSON_FILE}.interim" | jq -er --arg JQNEWCMD "${NEWCMD}" '.cmd = $JQNEWCMD'  > "${MOM_JSON_FILE}.interim2"




################################################
# Add a JAVA_OPTS_PRE section to the json file #
################################################

# 
# We set the "${NEWOPTS}" bash variable to the jq "$JAVA_OPTS_PRE" var.  Then use jq to add the "JAVA_OPTS_PRE" object to the json file's .env object.
#

#NEWOPTS='{"JAVA_OPTS_PRE": "-Dcom.sun.management.jmxremote  -Dcom.sun.management.jmxremote.ssl=false  -Dcom.sun.management.jmxremote.registry.ssl=false  -Dcom.sun.management.jmxremote.authenticate=false  -Dcom.sun.management.jmxremote.local.only=false  -Dcom.sun.management.jmxremote.host=0.0.0.0  -Dcom.sun.management.jmxremote.ssl.config.file=null  -Dcom.sun.management.jmxremote.ssl.enabled.cipher.suites=null  -Dcom.sun.management.jmxremote.ssl.enabled.protocols=null  -Dcom.sun.management.jmxremote.ssl.need.client.auth=false"}'

NEWOPTS='-Dcom.sun.management.jmxremote  -Dcom.sun.management.jmxremote.ssl=false  -Dcom.sun.management.jmxremote.registry.ssl=false  -Dcom.sun.management.jmxremote.authenticate=false  -Dcom.sun.management.jmxremote.local.only=false  -Dcom.sun.management.jmxremote.host=0.0.0.0  -Dcom.sun.management.jmxremote.ssl.config.file=null  -Dcom.sun.management.jmxremote.ssl.enabled.cipher.suites=null  -Dcom.sun.management.jmxremote.ssl.enabled.protocols=null  -Dcom.sun.management.jmxremote.ssl.need.client.auth=false'

cat "${MOM_JSON_FILE}.interim2" | jq -er --arg JAVA_OPTS_PRE "${NEWOPTS}" '.env += {$JAVA_OPTS_PRE}' > "${MOM_JSON_FILE}.interim3"






################################################
# Add a portDefinition to the json file        #
################################################

cat "${MOM_JSON_FILE}.interim3" | jq -er --arg NEWPORTDEF "${NEW_PORT_DEF}" '.portDefinitions +=  [{ "labels": { "VIP_1": "/jmx:9999" }, "name": "jmx", "protocol": "tcp", "port": 10100 }] ' > ${MOM_JSON_FILE}.interim4




if [ $( echo "${MOM_JSON_FILE}" | egrep -c -i '.json$' ) -gt 0  ];then 
  # Change filename from <something>.JSON to <something>-jmx.JSON;
  NEW_MOM_JSON_FILE=$( echo "${MOM_JSON_FILE}" | sed -e 's|[.][jJ][sS][oO][nN]|-jmx.JSON|' )
else 
  # Change filename from <something>      to <something>-jmx.JSON;
  NEW_MOM_JSON_FILE=$( echo ${MOM_JSON_FILE} | sed -e 's|$|-jmx.JSON|' )
fi



################################################
# Change the .id in the json file (add "-jmx") #
################################################

ID=$( cat ${MOM_JSON_FILE}.interim4 | jq -er '.id' )
NEW=$( echo $ID  | sed -e 's|$|-jmx|' )
cat ${MOM_JSON_FILE}.interim4 | jq -er --arg NEW "${NEW}" '.id = $NEW' > "${MOM_JSON_FILE}.interim5"


##############################################################
# Change the DCOS_SERVICE_NAME in the json file (add "-jmx") #
##############################################################

SERVICE_NAME=$( cat ${MOM_JSON_FILE}.interim5 | jq -er '.labels.DCOS_SERVICE_NAME' )
SERVICE_NAME="${SERVICE_NAME}-jmx"
cat ${MOM_JSON_FILE}.interim5 | jq -er --arg SNAME "${SERVICE_NAME}" '.labels.DCOS_SERVICE_NAME = $SNAME'  > "${NEW_MOM_JSON_FILE}"





echo "DONE: New file is ${NEW_MOM_JSON_FILE}"


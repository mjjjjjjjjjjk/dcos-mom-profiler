#!/bin/bash


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
# Pull 'cmd' out of json file;
#

CMD=$( cat "$MOM_JSON_FILE" | jq -er '.cmd')


echo "################################################"
echo $CMD
echo "################################################"



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

cat "${MOM_JSON_FILE}" | jq -er --arg JQNEWCMD "${NEWCMD}" '.cmd = $JQNEWCMD'  > "${MOM_JSON_FILE}.interim"


# 
# We set the "${NEWOPTS}" bash variable to the jq "$JAVA_OPTS_PRE" var.  Then use jq to add the "JAVA_OPTS_PRE" object to the json file's .env object.
#

#NEWOPTS='{"JAVA_OPTS_PRE": "-Dcom.sun.management.jmxremote  -Dcom.sun.management.jmxremote.ssl=false  -Dcom.sun.management.jmxremote.registry.ssl=false  -Dcom.sun.management.jmxremote.authenticate=false  -Dcom.sun.management.jmxremote.local.only=false  -Dcom.sun.management.jmxremote.host=0.0.0.0  -Dcom.sun.management.jmxremote.ssl.config.file=null  -Dcom.sun.management.jmxremote.ssl.enabled.cipher.suites=null  -Dcom.sun.management.jmxremote.ssl.enabled.protocols=null  -Dcom.sun.management.jmxremote.ssl.need.client.auth=false"}'

NEWOPTS='-Dcom.sun.management.jmxremote  -Dcom.sun.management.jmxremote.ssl=false  -Dcom.sun.management.jmxremote.registry.ssl=false  -Dcom.sun.management.jmxremote.authenticate=false  -Dcom.sun.management.jmxremote.local.only=false  -Dcom.sun.management.jmxremote.host=0.0.0.0  -Dcom.sun.management.jmxremote.ssl.config.file=null  -Dcom.sun.management.jmxremote.ssl.enabled.cipher.suites=null  -Dcom.sun.management.jmxremote.ssl.enabled.protocols=null  -Dcom.sun.management.jmxremote.ssl.need.client.auth=false'

cat "${MOM_JSON_FILE}.interim" | jq -er --arg JAVA_OPTS_PRE "${NEWOPTS}" '.env += {$JAVA_OPTS_PRE}' > "${MOM_JSON_FILE}.JMX"


echo "DONE: New file is ${MOM_JSON_FILE}.JMX"


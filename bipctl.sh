#!/bin/sh
# bipctl.sh - control BI Publisher services
# Usage: bipctl.sh <start|stop|status>
################################################################################
PROGNAME="$(basename "$0")"
WLST_CMD_FILE="${PROGNAME}.py"
WLS_CFG_FILE="${HOME}/.wls-config.secure"
WLS_KEY_FILE="${HOME}/.wls-key.secure"
WLST_CMD="java -d64 -Dweblogic.security.SSL.ignoreHostnameVerification=true -Dweblogic.security.TrustKeyStore=DemoTrust weblogic.WLST"

#-------------------------------------------------------------------------------
# Customization
#-------------------------------------------------------------------------------
WLS_ADMIN_SERVER_URL="t3://$(hostname -s):7001"
WLS_NM_HOST=$(hostname -s)
WLS_NM_PORT="9556"
WLS_HOME="/u01/mw/wls/wlserver_10.3"
WLS_DOMAIN_HOME="/u01/mw/wls/user_projects/domains/bifoundation_domain"
export PATH=$WLS_HOME/server/bin:$DOMAIN_HOME/bin:$PATH

#-------------------------------------------------------------------------------
# Functions
#-------------------------------------------------------------------------------
usage() {
	echo "Usage: ${PROGNAME} <start|stop|status>"
}

createWLSConfigs() {
	if ! [ -f ${WLS_CFG_FILE} ] || ! [ -f ${WLS_KEY_FILE} ] ; then
		local l_username l_password l_adminurl
		echo "WLS configuration and key files do not exist. Creating."
		echo "#######################################################"
		
		echo "Enter admin url (ex. t3://$(hostname -s):7001): "
		read l_adminurl
		echo "Enter weblogic username: "
		read l_username
		echo "Enter weblogic password: "
		stty -echo
		read l_password
		stty echo
	
		$JAVA_HOME/bin/java weblogic.Admin \
                            -adminurl "${l_adminurl}" \
                            -username ${l_username} \
                            -password ${l_password} \
                            -userconfigfile "${WLS_CFG_FILE}" \
                            -userkeyfile "${WLS_KEY_FILE}" \
                            -STOREUSERCONFIG
			
		if ! [ -f "${WLS_CFG_FILE}"  ] || ! [ -f "${WLS_KEY_FILE}" ] ; then
			echo "An error occured while creating files. Exiting."
			exit 1
		fi
		
		chmod 600 "${WLS_CFG_FILE}" "${WLS_KEY_FILE}"
		ls -l "${WLS_CFG_FILE}" "${WLS_KEY_FILE}"
		echo "#######################################################"
		echo "Files created. Please restart the script."
		exit 0
	fi
	
	return 0
}

statusBIP() {
	cat << EOF > "${WLST_CMD_FILE}"
connect(userConfigFile='${WLS_CFG_FILE}',userKeyFile='${WLS_KEY_FILE}',url='${WLS_ADMIN_SERVER_URL}')
domainRuntime()
serverLifeCycles = cmo.getServerLifeCycleRuntimes()
for serverLifeCycle in serverLifeCycles:
	print 'SERVER=' + serverLifeCycle.getName() + ', STATUS=' + serverLifeCycle.getState()
exit()
EOF
	${WLST_CMD} ${WLST_CMD_FILE} | egrep -v "BEA-090898|BEA-090905|BEA-090906|^NMProcess"
}

startBIP() {
	cat << EOF > "${WLST_CMD_FILE}"
startNodeManager(NodeManagerHome='$WLS_HOME/common/nodemanager')
nmConnect(userConfigFile='${WLS_CFG_FILE}',userKeyFile='${WLS_KEY_FILE}',host='${WLS_NM_HOST}',port='${WLS_NM_PORT}',domainName='$(basename ${WLS_DOMAIN_HOME})',domainDir='${WLS_DOMAIN_HOME}')
nmStart('AdminServer')
connect(userConfigFile='${WLS_CFG_FILE}',userKeyFile='${WLS_KEY_FILE}',url='${WLS_ADMIN_SERVER_URL}')
domainRuntime()
serverLifeCycles = cmo.getServerLifeCycleRuntimes()
for serverLifeCycle in serverLifeCycles:
	if (serverLifeCycle.getState() != 'RUNNING'):
		print 'Starting Server: ' + serverLifeCycle.getName()
		start(serverLifeCycle.getName(), 'Server')
exit()
EOF
	${WLST_CMD} ${WLST_CMD_FILE} | egrep -v "BEA-090898|BEA-090905|BEA-090906|^NMProcess"
}

stopBIP() {
	cat << EOF > "${WLST_CMD_FILE}"
nmConnect(userConfigFile='${WLS_CFG_FILE}',userKeyFile='${WLS_KEY_FILE}',host='${WLS_NM_HOST}',port='${WLS_NM_PORT}',domainName='$(basename ${WLS_DOMAIN_HOME})',domainDir='${WLS_DOMAIN_HOME}')
connect(userConfigFile='${WLS_CFG_FILE}',userKeyFile='${WLS_KEY_FILE}',url='${WLS_ADMIN_SERVER_URL}')
domainRuntime()
serverLifeCycles = cmo.getServerLifeCycleRuntimes()
for serverLifeCycle in serverLifeCycles:
	if (serverLifeCycle.getState() == 'RUNNING') and (serverLifeCycle.getName() != 'AdminServer'):
		print 'Stopping Server: ' + serverLifeCycle.getName()
		nmKill(serverLifeCycle.getName())
nmKill('AdminServer')
stopNodeManager()
exit()
EOF
	${WLST_CMD} ${WLST_CMD_FILE} | egrep -v "BEA-090898|BEA-090905|BEA-090906|^NMProcess"
}


################################################################################
# MAIN
################################################################################
. ${WLS_HOME}/server/bin/setWLSEnv.sh > /dev/null 2>&1
createWLSConfigs

case $1 in
start)	startBIP  ;;
stop)   stopBIP   ;;
status) statusBIP ;;
*)      usage     ;;
esac

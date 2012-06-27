#! /bin/sh

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

# Oracle SQL*Plus configuration
ORACLE_HOME=/opt/oracle

PATH=$PATH:$ORACLE_HOME
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ORACLE_HOME
TNS_ADMIN=$ORACLE_HOME
NLS_LANG="AMERICAN_AMERICA.WE8MSWIN1252"

export ORACLE_HOME PATH LD_LIBRARY_PATH TNS_ADMIN NLS_LANG

check_sqlplus() {
    if [ ! -x $ORACLE_HOME/sqlplus ]; then
	echo "CRITICAL - sqlplus binary not found!"
	exit $STATE_CRITICAL
    fi
}

version() {
	echo "Nagios plugins for Oracle monitoring version 1.0.2"
	echo "Plugins come with ABSOLUTELY NO WARRANTY. You may redistribute\ncopies of the plugins under the terms of the GNU General Public License v3 or later.\nFor more information about these matters, see the file named COPYING.\n"
}

support() {
	echo "Send email to contact@gstlt.info if you have questions regarding use of this software."
}


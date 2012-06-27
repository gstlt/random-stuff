#! /bin/sh
#
# Check of user sessions on Oracle Application Server (Terminal)
# Terminal = Hostname
#
# If one have multiple AS'es on one host - it shows sessions
# on that "Terminal"
# 
# To be used with Nagios-PNP only since it won't return any
# alerts instead of database unreachable
#
# 2009 gstlt, Grzegorz Adamowicz
# http://gstlt.info

PROGNAME=`basename $0`
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
REVISION=`echo '$Revision: 1.00 $' | sed -e 's/[^0-9.]//g'`

if [ -x $PROGPATH/the_utils.sh ]; then
        . $PROGPATH/the_utils.sh
fi


print_usage() {
  echo "Usage:"
  echo "  $PROGNAME --terminal TERMINAL_NAME OracleSID username pass"
}

print_help() {
  print_revision $PROGNAME $REVISION
  echo ""
  print_usage
  echo ""
  echo ""
  support
}

case "$1" in
1)
    cmd='--tns'
    ;;
2)
    cmd='--db'
    ;;
*)
    cmd="$1"
    ;;
esac

# Information options
case "$cmd" in
--help)
		print_help
    exit $STATE_OK
    ;;
-h)
		print_help
    exit $STATE_OK
    ;;
--version)
		print_revision $PLUGIN $REVISION
    exit $STATE_OK
    ;;
-V)
		print_revision $PLUGIN $REVISION
    exit $STATE_OK
    ;;
esac

# Hunt down a reasonable ORACLE_HOME
if [ -z "$ORACLE_HOME" ] ; then
	# Adjust to taste
	for oratab in /var/opt/oracle/oratab /etc/oratab
	do
	[ ! -f $oratab ] && continue
	ORACLE_HOME=`IFS=:
		while read SID ORACLE_HOME junk;
		do
			if [ "$SID" = "$2" -o "$SID" = "*" ] ; then
				echo $ORACLE_HOME;
				exit;
			fi;
		done < $oratab`
	[ -n "$ORACLE_HOME" ] && break
	done
fi
# Last resort
[ -z "$ORACLE_HOME" -a -d $PROGPATH/oracle ] && ORACLE_HOME=$PROGPATH/oracle

if [ -z "$ORACLE_HOME" -o ! -d "$ORACLE_HOME" ] ; then
	echo "Cannot determine ORACLE_HOME for sid $2"
	exit $STATE_UNKNOWN
fi
PATH=$PATH:$ORACLE_HOME/bin
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ORACLE_HOME/lib
export ORACLE_HOME PATH LD_LIBRARY_PATH

case "$cmd" in
--terminal)
    result=`sqlplus -s ${4}/${5}@${3} << EOF
set pagesize 0
set numf '9999999'
select count(*) from v\\$session where program='frmweb.exe' and 
terminal='${2}';
EOF`
#echo "RESULT: $result"
#echo "OPTIONS: ${1} ${2} ${3} ${4} ${5} ${6}"

    if [ -n "`echo $result | grep ORA-`" ] ; then
      error=` echo "$result" | grep "ORA-" | head -1`
      echo "CRITICAL - $error"
      exit $STATE_CRITICAL
    fi

    sessions=`echo "$result" | awk '/[0-9\.]+/ {printf "%d",$1}'` 
#    echo "Sessons on ${2} = $sessions"
    
    echo "OK - Total sessions on ${2}: $sessions|Total=$sessions;;;; "
    exit $STATE_OK
    ;;

*)
    print_usage
		exit $STATE_UNKNOWN
esac

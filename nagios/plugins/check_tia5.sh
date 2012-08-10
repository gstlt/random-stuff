#! /bin/sh
#
# latigid010@yahoo.com
# 01/06/2000
#
#  This Nagios plugin was created to check Oracle status
#
# Additional checks and changes added by gstlt (2008-2011) - Grzegorz Adamowicz
# http://gstlt.info

PROGNAME=`basename $0`
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`

#echo $0

if [ -x $PROGPATH/the_utils.sh ]; then
	. $PROGPATH/the_utils.sh
fi


print_usage() {
  echo "Usage:"
  echo "  $PROGNAME --prints <ORACLE_SID> <USER> <PASS> <MAXBROKEN> <MAXQUEUED>"
  echo "  $PROGNAME --batchjobs <ORACLE_SID> <USER> <PASS> <MAXBROKEN> <MAXQUEUED>"
  echo "  $PROGNAME --batches <ORACLE_SID> <USER> <PASS>"
  echo "  $PROGNAME --help"
  echo "  $PROGNAME --version"
}

print_help() {
  version
  echo ""
  print_usage
  echo ""
  echo "Check TIA status"
  echo ""
  echo "--prints"
  echo "   Check TIA prints status in specified database"
  echo "       --->  Requires Oracle user/password, SID, MAXBROKEN prints and MAXQUEUED specified."
  echo "       		--->  Requires grant select on print_request"
  echo "--batchjobs"
  echo "   Check TIA prints status in specified database"
  echo "       --->  Requires Oracle user/password, SID, MAXBROKEN prints and MAXQUEUED specified."
  echo "       		--->  Requires grant select on print_request"
  echo "--batches"
  echo "   Check TIA batches status in specified database"
  echo "       --->  Requires Oracle user/password, SID."
  echo "       		--->  Requires grant select on demon_control an v$session"
  echo "--help"
  echo "   Print this help screen"
  echo "--version"
  echo "   Print version and license information"
  echo ""
  echo "If the plugin doesn't work, check that the ORACLE_HOME environment"
  echo "variable is set, that ORACLE_HOME/bin is in your PATH, and the"
  echo "tnsnames.ora file is locatable and is properly configured."
  echo ""
  echo "When checking local database status your ORACLE_SID is case sensitive."
  echo ""
  echo "If you want to use a default Oracle home, add in your oratab file:"
  echo "*:/opt/app/oracle/product/7.3.4:N"
  echo ""
  support
}

#cmd="$1"

# Information options
case "$1" in
--help)
		print_help
    exit $STATE_OK
    ;;
-h)
		print_help
    exit $STATE_OK
    ;;
--version)
		echo $PROGNAME
		version
    exit $STATE_OK
    ;;
-V)
		echo $PROGNAME
		version
    exit $STATE_OK
    ;;
*)
		cmd="$1"
	;;
esac

check_sqlplus

case "$cmd" in
--prints)
    time_start=$(date +%s.%N)
    result=`sqlplus -s ${3}/${4}@${2} << EOF
set pagesize 0;
select  
(select count(request_id)
from print_request
where request_exe_date  between trunc(sysdate) and trunc(sysdate)+1
and REQUEST_EMODE='XP')X_B,
(select count(request_id)
from print_request
where request_exe_date  between trunc(sysdate) and trunc(sysdate)+1
and REQUEST_EMODE='XE')E,
(select count(request_id)
from print_request
where request_exe_date  between trunc(sysdate) and trunc(sysdate)+1
and REQUEST_EMODE IN('XH','X','XL'))O_T_L
from dual;
EOF`
    time_end=$(date +%s.%N)
    elapsed_time=$(echo "$time_end - $time_start" | bc | sed 's/^\./0./')

    if [ -n "`echo $result | grep ORA-`" ] ; then
      error=` echo "$result" | grep "ORA-" | head -1`
      echo "CRITICAL - $error|time=${elapsed_time}s;;;;"
      exit $STATE_CRITICAL
    fi

    result1=`echo $result | sed --posix -r 's/^([A-Za-z0-9\_]*)\s([0-9\.]*)\s([0-9\.]*)\s([0-9\.]*)\s([0-9\.]*)\s[a-zA-Z0-9\.]*\s[0-9\.]*\s[a-zA-Z]*\s[a-zA-Z]*\s[a-zA-Z]*$/\2 \4 \5/' | awk ' {if ($0 ~ /[a-zA-Z]+/) print "0 0 0"; else print $0}'`
    pr_total=`echo "$result1" | awk '/[0-9\.]+/ {printf "%d",$1}'` 
    pr_broken=`echo "$result1" | awk '/[0-9\.]+/ {printf "%d",$2}'` 
    pr_queue=`echo "$result1" | awk '/[0-9\.]+/ {printf "%d",$3}'` 

    if [ "$pr_broken" -eq ${5} ] ; then
  	echo "WARNING - Prints with error: $pr_broken, Prints in queue: $pr_queue|Total=$pr_total;;;; Broken=$pr_broken;;;; Queued=$pr_queue;;;; time=${elapsed_time}s;;;;"
	exit $STATE_WARNING
    fi
    if [ "$pr_broken" -gt ${5} ] ; then
  	echo "CRITICAL - Prints with error: $pr_broken, Prints in queue: $pr_queue, Total: $pr_total|Total=$pr_total;;;; Broken=$pr_broken;;;; Queued=$pr_queue;;;; time=${elapsed_time}s;;;;"
	exit $STATE_CRITICAL
    fi
    if [ "$pr_queue" -ge ${6} ] ; then
  	echo "WARNING  - Too many prints in queue. Total: $pr_total, Queue: $pr_queue|Total=$pr_total;;;; Broken=$pr_broken;;;; Queued=$pr_queue;;;; time=${elapsed_time}s;;;;"
	exit $STATE_WARNING
    fi

    echo "OK - Total: $pr_total, Errors: $pr_broken, Queued: $pr_queue|Total=$pr_total;;;; Broken=$pr_broken;;;; Queued=$pr_queue;;;; time=${elapsed_time}s;;;;"
    exit $STATE_OK
    ;;

--batchjobs)
    time_start=$(date +%s.%N)
    result=`sqlplus -s ${3}/${4}@${2} << EOF
set pagesize 0;
select
(select count(request_id)
from print_request
where request_exe_date  between trunc(sysdate) and trunc(sysdate)+1
and REQUEST_EMODE='BP') B,
(select count(*) from bat_request where status = 'ERR' and bat_queue = to_char(1) and run_date <= sysdate) E,
((select count(*) from bat_request where (status is null or status = 'RUN') and bat_queue = to_char(1) and run_date <= sysdate) + 
 (select count(request_id) from print_request where request_exe_date  between trunc(sysdate) and trunc(sysdate)+1 and REQUEST_EMODE IN('BH') and request_id not in (select request_id from bat_request where (status is null or status = 'RUN') and bat_queue = to_char(1) and run_date <= sysdate))) O_T_L
 from dual;
EOF`

    time_end=$(date +%s.%N)
    elapsed_time=$(echo "$time_end - $time_start" | bc | sed 's/^\./0./')

    if [ -n "`echo $result | grep ORA-`" ] ; then
      error=` echo "$result" | grep "ORA-" | head -1`
      echo "CRITICAL - $error|time=${elapsed_time}s;;;;"
      exit $STATE_CRITICAL
    fi

    result1=`echo $result | sed --posix -r 's/^([A-Za-z0-9\_]*)\s([0-9\.]*)\s([0-9\.]*)\s([0-9\.]*)\s([0-9\.]*)\s[a-zA-Z0-9\.]*\s[0-9\.]*\s[a-zA-Z]*\s[a-zA-Z]*\s[a-zA-Z]*$/\2 \4 \5/' | awk ' {if ($0 ~ /[a-zA-Z]+/) print "0 0 0"; else print $0}'`
    bat_total=`echo "$result1" | awk '/[0-9\.]+/ {printf "%d",$1}'` 
    bat_broken=`echo "$result1" | awk '/[0-9\.]+/ {printf "%d",$2}'` 
    bat_queue=`echo "$result1" | awk '/[0-9\.]+/ {printf "%d",$3}'` 
    #ts_pctx=`echo "$result1" | awk '/[0-9\.]+/ {printf "%.2f",$2}'`
#    echo "All = $pr_total, Broken = $pr_broken, In queue = $pr_queue"
    
    if [ "$bat_broken" -eq ${5} ] ; then
  	echo "WARNING - Batch jobs with error: $bat_broken, Batch jobs in queue: $bat_queue|Total=$bat_total;;;; Broken=$bat_broken;;;; Queued=$bat_queue;;;; time=${elapsed_time}s;;;;"
	exit $STATE_WARNING
    fi
    if [ "$bat_broken" -gt ${5} ] ; then
  	echo "CRITICAL - Batch jobs with error: $bat_broken, Batch jobs in queue: $bat_queue, Total: $bat_total|Total=$bat_total;;;; Broken=$bat_broken;;;; Queued=$bat_queue;;;; time=${elapsed_time}s;;;;"
	exit $STATE_CRITICAL
    fi
    if [ "$bat_queue" -ge ${6} ] ; then
  	echo "WARNING  - Too many batch jobs in queue. Total: $bat_total, Queue: $bat_queue|Total=$bat_total;;;; Broken=$bat_broken;;;; Queued=$bat_queue;;;; time=${elapsed_time}s;;;;"
	exit $STATE_WARNING
    fi

    echo "OK - Total: $bat_total, Errors: $bat_broken, Queued: $bat_queue|Total=$bat_total;;;; Broken=$bat_broken;;;; Queued=$bat_queue;;;; time=${elapsed_time}s;;;;"
    exit $STATE_OK
    ;;

--batches)
    time_start=$(date +%s.%N)
    result=`sqlplus -s ${3}/${4}@${2} << EOF
set pagesize 0;
select name, job from demon_control
where session_id not in (select audsid from v\\$session);
EOF`
    time_end=$(date +%s.%N)
    elapsed_time=$(echo "$time_end - $time_start" | bc | sed 's/^\./0./')

    if [ -n "`echo $result | grep ORA-`" ] ; then
      error=` echo "$result" | grep "ORA-" | head -1`
      echo "CRITICAL - $error|time=${elapsed_time}s;;;;"
      exit $STATE_CRITICAL
    fi

    if [ -n "`echo $result | grep 'no rows selected'`" ] ; then
	error="OK - All batches up.|time=${elapsed_time}s;;;;"
	echo $error
	exit $STATE_OK
    fi

    result1=`echo $result | sed -e 's/[0-9]* rows selected.//g' | sed --posix -r 's/([A-Z][0-9]{4})\s([0-9])/\1(Job \2)/g'  | awk '{ print $0 }'`
    #echo "Dupa: $result1"
    bacz_down=`echo "$result1"`

    echo "CRITICAL - Following batch(es) is/are DOWN on ${2}: $bacz_down|time=${elapsed_time}s;;;;"
    exit $STATE_CRITICAL
    ;;
*)
    print_usage
		exit $STATE_UNKNOWN
esac

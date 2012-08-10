#! /bin/sh
#
# Original script by:
# latigid010@yahoo.com
# 01/06/2000
#
#  This Nagios plugin was created to check Oracle status
#
# Additional checks and changes added by gstlt (2008-2011) - Grzegorz Adamowicz
# http://gstlt.info


PROGNAME=`basename $0`
REVISION="0.8"
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`

. $PROGPATH/the_utils.sh


print_usage() {
  echo "Usage:"
  echo "  $PROGNAME --login <ORACLE_SID>"
  echo "  $PROGNAME --real-login <ORACLE_SID> <USER> <PASS>"
  echo "  $PROGNAME --usersession <ORACLE_SID> <USER> <PASS> <CRITICAL> <WARNING>"
  echo "  $PROGNAME --tablespace <ORACLE_SID> <USER> <PASS> <TABLESPACE> <CRITICAL> <WARNING>"
  echo "  $PROGNAME --asm <ORACLE_SID> <USER> <PASS> <DISKGROUP_NAME> <WARNING_MB> <CRITICAL_MB>"
  echo "  $PROGNAME --pcm <ORACLE_SID> <USER> <PASS>"
  echo "  $PROGNAME --help"
  echo "  $PROGNAME --version"
}

print_help() {
  print_revision $PROGNAME $REVISION
  echo ""
  print_usage
  echo ""
  echo ""
  echo "If the plugin doesn't work, check that the ORACLE_HOME environment"
  echo "variable is set, that ORACLE_HOME/bin is in your PATH, and the"
  echo "tnsnames.ora file is locatable and is properly configured."
  echo ""
  echo "When checking local database status your ORACLE_SID is case sensitive."
  echo ""
  ncdc_support
}

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
		print_revision $PLUGIN $REVISION
    exit $STATE_OK
    ;;
-V)
		print_revision $PLUGIN $REVISION
    exit $STATE_OK
    ;;
*)
    cmd="$1"
    ;;
esac


case "$cmd" in
--login)
	time_start=$(date +%s.%N)
    loginchk=`sqlplus dummy/user@$2 < /dev/null`
    time_end=$(date +%s.%N)
    elapsed_time=$(echo "$time_end - $time_start" | bc | sed 's/^\./0./')
    loginchk2=` echo  $loginchk | grep -c ORA-01017`
    if [ ${loginchk2} -eq 1 ] ; then
	echo "OK - dummy login connected in $elapsed_time s|time=${elapsed_time}s;;;;"
	exit $STATE_OK
    else
	loginchk3=` echo "$loginchk" | grep "ORA-" | head -1`
	echo "CRITICAL - $loginchk3|time=${elapsed_time}s;;;;"
	exit $STATE_CRITICAL
    fi
    ;;
--real-login)
	time_start=$(date +%s.%N)
    loginchk=`sqlplus $3/$4@$2 < /dev/null`
    time_end=$(date +%s.%N)
    elapsed_time=$(echo "$time_end - $time_start" | bc | sed 's/^\./0./')
    ### printf "Elapsed time: %.3f\n" $(echo "$elapsed_time")
    loginchk2=` echo  $loginchk | grep -c ORA-`
    if [ ${loginchk2} -eq 0 ] ; then
	echo "OK - Connected to $2 in $elapsed_time s|time=${elapsed_time}s;;;;"
	exit $STATE_OK
    else
	loginchk3=` echo "$loginchk" | grep "ORA-" | head -1`
	echo "CRITICAL - $loginchk3|time=${elapsed_time}s;;;;"
	exit $STATE_CRITICAL
    fi
    ;;
--usersession)
	time_start=$(date +%s.%N)
    result=`sqlplus -s ${3}/${4}@${2} << EOF
set pagesize 0;
select count(sid) from v\\$session
where upper(program)='FRMWEB.EXE';
EOF`
    time_end=$(date +%s.%N)
    elapsed_time=$(echo "$time_end - $time_start" | bc | sed 's/^\./0./')

    if [ -n "`echo $result | grep ORA-`" ] ; then
      error=` echo "$result" | grep "ORA-" | head -1`
      echo "CRITICAL - $error|time=${elapsed_time}s;;;;"
      exit $STATE_CRITICAL
    fi

    if [ -n "`echo $result | grep 'no rows selected'`" ] ; then
        error="CRITICAL - No user sessions? Something is wrong!|time=${elapsed_time}s;;;;"
        echo $error
        exit $STATE_CRITICAL
    fi

    sid_total=`echo "$result" | awk '/[0-9]+/ {printf "%d",$1}'`
    #echo "Total: $sid_total"

    echo "OK - User sessions on ${2}: $sid_total|'${2} sessions number'=${sid_total};;;; time=${elapsed_time}s;;;;"
    exit $STATE_OK
    ;;
--tablespace)
    if [ ${6} -lt ${7} ] ; then
	echo "UNKNOWN - Warning level is more than Critical"
	exit $STATE_UNKNOWN
    fi
    result=`sqlplus -s ${3}/${4}@${2} << EOF
set pagesize 0;
set numf '99999999.99';
SELECT d.tablespace_name, NVL(a.bytes / 1024 / 1024, 0) Rozmiar,
DECODE(d.contents,'UNDO', NVL(u.bytes, 0)/1024/1024, NVL(a.bytes - NVL(f.bytes, 0), 0)/1024/1024) Zajete,
DECODE(d.contents,'UNDO', NVL(u.bytes / a.bytes * 100, 0), NVL((a.bytes - NVL(f.bytes, 0)) / a.bytes * 100, 0)) Procent,
DECODE(d.contents,'UNDO', NVL(a.bytes - NVL(u.bytes, 0), 0)/1024/1024, NVL(f.bytes, 0) / 1024 / 1024) Wolne,
d.status, a.count, d.contents, d.extent_management, d.segment_space_management
FROM sys.dba_tablespaces d,
(SELECT tablespace_name, SUM(bytes) bytes, COUNT(file_id) count from dba_data_files GROUP BY tablespace_name) a,
(select tablespace_name, sum(bytes) bytes from dba_free_space group by tablespace_name) f,
(SELECT tablespace_name, SUM(bytes) bytes FROM dba_undo_extents WHERE status IN ('ACTIVE','UNEXPIRED') GROUP BY tablespace_name) u
WHERE d.tablespace_name = a.tablespace_name(+)
AND d.tablespace_name = f.tablespace_name(+)
AND d.tablespace_name = u.tablespace_name(+)
AND NOT (d.extent_management = 'LOCAL' AND d.contents = 'TEMPORARY')
AND d.tablespace_name like '${5}'
UNION ALL SELECT d.tablespace_name, NVL(a.bytes / 1024 / 1024, 0),
NVL(t.bytes, 0)/1024/1024,
NVL(t.bytes / a.bytes * 100, 0),
(NVL(a.bytes ,0)/1024/1024 - NVL(t.bytes, 0)/1024/1024),
d.status, a.count, d.contents, d.extent_management, d.segment_space_management
FROM sys.dba_tablespaces d,
(select tablespace_name, sum(bytes) bytes, count(file_id) count from dba_temp_files group by tablespace_name) a,
(select ss.tablespace_name , sum((ss.used_blocks*ts.blocksize)) bytes
  from gv\\$sort_segment ss, sys.ts\\$ ts where ss.tablespace_name = ts.name group by ss.tablespace_name) t
  WHERE d.tablespace_name = a.tablespace_name(+)
  AND d.tablespace_name = t.tablespace_name(+)
  AND d.extent_management = 'LOCAL'
  AND d.contents = 'TEMPORARY'
  and d.tablespace_name like '${5}'
  ORDER BY 1;
EOF`

    if [ -n "`echo $result | grep ORA-`" ] ; then
      error=` echo "$result" | grep "ORA-" | head -1`
      echo "CRITICAL - $error"
      exit $STATE_CRITICAL
    fi

    result1=`echo $result | sed --posix -r 's/^([A-Za-z0-9\_]*)\s([0-9\.]*)\s([0-9\.]*)\s([0-9\.]*)\s([0-9\.]*)\s[a-zA-Z0-9\.]*\s[0-9\.]*\s[a-zA-Z]*\s[a-zA-Z]*\s[a-zA-Z]*$/\2 \4 \5/' | awk ' {if ($0 ~ /[a-zA-Z]+/) print "0 0 0"; else print $0}'`
    ts_free=`echo "$result1" | awk '/[0-9\.]+/ {printf "%d",$3}'`
    ts_total=`echo "$result1" | awk '/[0-9\.]+/ {printf "%d",$1}'`
    ts_pct=`echo "$result1" | awk '/[0-9\.]+/ {printf "%d",$2}'`
    ts_pctx=`echo "$result1" | awk '/[0-9\.]+/ {printf "%.2f",$2}'`

    if [ "$ts_free" -eq 0 -a "$ts_total" -eq 0 -a "$ts_pct" -eq 0 ] ; then
        echo "No data returned by Oracle - tablespace $5 not found?"
        exit $STATE_UNKNOWN
    fi
    if [ "$ts_pct" -ge ${6} ] ; then
  	echo "${2} : ${5} CRITICAL - $ts_pctx% used [ $ts_free / $ts_total MB available ]|${5}=$ts_pctx%;${7};${6};0;100 [check_oracle.ncdc]"
	exit $STATE_CRITICAL
    fi
    if [ "$ts_pct" -ge ${7} ] ; then
  	echo "${2} : ${5} WARNING  - $ts_pctx% used [ $ts_free / $ts_total MB available ]|${5}=$ts_pctx%;${7};${6};0;100 [check_oracle.ncdc]"
	exit $STATE_WARNING
    fi
    echo "${2} : ${5} OK - $ts_pctx% used [ $ts_free / $ts_total MB available ]|${5}=$ts_pctx%;${7};${6};0;100 [check_oracle.ncdc]"
    exit $STATE_OK
    ;;

--asm)
	time_start=$(date +%s.%N)
    result=`sqlplus -s ${3}/${4}@${2} << EOF
set pagesize 0;
select name, total_mb, free_mb from v\\$asm_diskgroup
where name='${5}';
EOF`
    time_end=$(date +%s.%N)
    elapsed_time=$(echo "$time_end - $time_start" | bc | sed 's/^\./0./')
    if [ -n "`echo $result | grep ORA-`" ] ; then
      error=` echo "$result" | grep "ORA-" | head -1`
      echo "CRITICAL - $error|time=${elapsed_time}s;;;;"
      exit $STATE_CRITICAL
    fi

    if [ -n "`echo $result | grep 'no rows selected'`" ] ; then
	error="CRITICAL - Where is ASM? (Wrong diskgroup name?)"
	echo "$error|time=${elapsed_time}s;;;;"
	exit $STATE_CRITICAL
    fi

    result1=`echo $result | sed -e 's/[0-9]* rows selected.//g' | sed --posix -r 's/([A-Za-z\_]+)\s([0-9]+)\s([0-9]+)$/\2 \3/g' | awk '{ print $0 }'`

    asm_total=`echo "$result1" | awk '/[0-9]+/ {printf "%d",$1}'`
    asm_free=`echo "$result1" | awk '/[0-9]+/ {printf "%d",$2}'`

    if [ "$asm_free" -lt ${7} ] ; then
  	echo "CRITICAL - Low disk space on ${5}! $asm_free MB/$asm_total MB|${5}=${asm_free}MB;${6};${7};0;${asm_total} time=${elapsed_time}s;;;;"
	exit $STATE_CRITICAL
    fi
    if [ "$asm_free" -lt ${6} ] ; then
  	echo "WARNING - Low disk space on ${5}! $asm_free MB/$asm_total MB|${5}=${asm_free}MB;${6};${7};0;${asm_total} time=${elapsed_time}s;;;;"
	exit $STATE_WARNING
    fi

    echo "OK - Free space on ${5}: $asm_free MB/$asm_total MB|${5}=${asm_free}MB;${6};${7};0;${asm_total} time=${elapsed_time}s;;;;"
    exit $STATE_OK
    ;;
--pcm)
	time_start=$(date +%s.%N)
    result=`sqlplus -s ${3}/${4}@${2} << EOF
set pagesize 0;
select count(eventstatus) from PCM_EVENT where
eventstatus='Unhandled'
and TIMESTAMP between trunc(sysdate) and trunc(sysdate)+1;
EOF`
    time_end=$(date +%s.%N)
    elapsed_time=$(echo "$time_end - $time_start" | bc | sed 's/^\./0./')

    if [ -n "`echo $result | grep ORA-`" ] ; then
      error=` echo "$result" | grep "ORA-" | head -1`
      echo "CRITICAL - $error|time=${elapsed_time}s;;;;"
      exit $STATE_CRITICAL
    fi

    events_num=`echo "$result" | awk '/[0-9]+/ {printf "%d",$1}'`
    #echo "Total: $events_num"

    if [ $events_num -eq "0" ]; then
        echo "OK - No unhandled events|Events=${events_num};;;; time=${elapsed_time}s;;;;"
        exit $STATE_OK
    else
        echo "CRITICAL - Unhandled events: $events_num|Events=${events_num};;;; time=${elapsed_time}s;;;;"
        exit $STATE_CRITICAL
    fi
    ;;
*)
	echo "Executed command ${1}"
    print_usage
		exit $STATE_UNKNOWN
esac

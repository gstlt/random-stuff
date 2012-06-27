#! /bin/sh
# Original author:
# latigid010@yahoo.com
# 01/06/2000
#
#  This Nagios plugin was created to check Oracle status
#
# Additional checks and changes added by gstlt (2008-2011) - Grzegorz Adamowicz
# http://gstlt.info

PROGNAME=`basename $0`
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`

if [ -x $PROGPATH/the_utils.sh ]; then
	. $PROGPATH/the_utils.sh
fi


print_usage() {
  echo "Usage:"
  echo "  $PROGNAME --tns <Oracle Sid or Hostname/IP address>"
  echo "  $PROGNAME --db <ORACLE_SID>"
  echo "  $PROGNAME --login <ORACLE_SID>"
  echo "  $PROGNAME --cache <ORACLE_SID> <USER> <PASS> <CRITICAL> <WARNING>"
  echo "  $PROGNAME --tablespace <ORACLE_SID> <USER> <PASS> <TABLESPACE> <CRITICAL> <WARNING>"
  echo "  $PROGNAME --tablesize <ORACLE_SID> <USER> <PASS> <TABLENAME> <CRITICAL> <WARNING>"
  echo "  $PROGNAME --asm <ORACLE_SID> <USER> <PASS> <DISKGROUP_NAME> <WARNING_MB> <CRITICAL_MB>"
  echo "  $PROGNAME --oranames <Hostname>"
  echo "  $PROGNAME --help"
  echo "  $PROGNAME --version"
}

print_help() {
  print_revision $PROGNAME $REVISION
  echo ""
  print_usage
  echo ""
  echo "Check Oracle status"
  echo ""
  echo "--tns SID/IP Address"
  echo "   Check remote TNS server"
  echo "--db SID"
  echo "   Check local database (search /bin/ps for PMON process) and check"
  echo "   filesystem for sgadefORACLE_SID.dbf"
  echo "--login SID"
  echo "   Attempt a dummy login and alert if not ORA-01017: invalid username/password"
  echo "--cache"
  echo "   Check local database for library and buffer cache hit ratios"
  echo "       --->  Requires Oracle user/password and SID specified."
  echo "       		--->  Requires select on v_\$sysstat and v_\$librarycache"
  echo "--tablespace"
  echo "   Check local database for tablespace capacity in ORACLE_SID"
  echo "       --->  Requires Oracle user/password specified."
  echo "       		--->  Requires select on dba_data_files and dba_free_space"
  echo "--tablesize"
  echo "   Check how much space takes table specified by the user - in megabytes"
  echo "       --->  Requires Oracle user/password specified."
  echo "       		--->  Requires select on user_extents table"

  echo "--asm"
  echo "   Check ASM diskgroup free space"
  echo "--oranames Hostname"
  echo "   Check remote Oracle Names server"
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

check_sqlplus

case "$cmd" in
--tns)
    tnschk=` tnsping $2`
    tnschk2=` echo  $tnschk | grep -c OK`
    if [ ${tnschk2} -eq 1 ] ; then 
	tnschk3=` echo $tnschk | sed -e 's/.*(//' -e 's/).*//'`
	echo "OK - reply time ${tnschk3} from $2"
	exit $STATE_OK
    else
	echo "No TNS Listener on $2"
	exit $STATE_CRITICAL
    fi
    ;;
--oranames)
    namesctl status $2 | awk '
    /Server has been running for:/ {
	msg = "OK: Up"
	for (i = 6; i <= NF; i++) {
	    msg = msg " " $i
	}
	status = '$STATE_OK'
    }
    /error/ {
	msg = "CRITICAL: " $0
	status = '$STATE_CRITICAL'
    }
    END {
	print msg
	exit status
    }'
    ;;
--db)
    pmonchk=`ps -ef | grep -v grep | grep -c "ora_pmon_${2}$"`
    if [ ${pmonchk} -ge 1 ] ; then
	echo "${2} OK - ${pmonchk} PMON process(es) running"
	exit $STATE_OK
    #if [ -f $ORACLE_HOME/dbs/sga*${2}* ] ; then
	#if [ ${pmonchk} -eq 1 ] ; then
    #utime=`ls -la $ORACLE_HOME/dbs/sga*$2* | cut -c 43-55`
	    #echo "${2} OK - running since ${utime}"
	    #exit $STATE_OK
	#fi
    else
	echo "${2} Database is DOWN"
	exit $STATE_CRITICAL
    fi
    ;;
--login)
    loginchk=`sqlplus dummy/user@$2 < /dev/null`
    loginchk2=` echo  $loginchk | grep -c ORA-01017`
    if [ ${loginchk2} -eq 1 ] ; then 
	echo "OK - dummy login connected"
	exit $STATE_OK
    else
	loginchk3=` echo "$loginchk" | grep "ORA-" | head -1`
	echo "CRITICAL - $loginchk3"
	exit $STATE_CRITICAL
    fi
    ;;
--cache)
    if [ ${5} -gt ${6} ] ; then
	echo "UNKNOWN - Warning level is less then Crit"
	exit $STATE_UNKNOWN
    fi
    result=`sqlplus -s ${3}/${4}@${2} << EOF
set pagesize 0
set numf '099999999D990'
-- set numf '9999999.99'
select (1-(pr.value/(dbg.value+cg.value)))*100
from v\\$sysstat pr, v\\$sysstat dbg, v\\$sysstat cg
where pr.name='physical reads'
and dbg.name='db block gets'
and cg.name='consistent gets';
EOF`

    if [ -n "`echo $result | grep ORA-`" ] ; then
      error=` echo "$result" | grep "ORA-" | head -1`
      echo "CRITICAL - $error"
      exit $STATE_CRITICAL
    fi

    buf_hr=`echo "$result" | awk '/^[0-9\. \t]+$/ {print int($1)}'` 
    buf_hrx=`echo "$result" | awk '/^[0-9\. \t]+$/ {print $1}'` 
    result=`sqlplus -s ${3}/${4}@${2} << EOF
set pagesize 0
set numf '099999999D990'
-- set numf '9999999.99'
select sum(lc.pins)/(sum(lc.pins)+sum(lc.reloads))*100
from v\\$librarycache lc;
EOF`
	
    if [ -n "`echo $result | grep ORA-`" ] ; then
      error=` echo "$result" | grep "ORA-" | head -1`
      echo "CRITICAL - $error"
      exit $STATE_CRITICAL
    fi

    lib_hr=`echo "$result" | awk '/^[0-9\. \t]+$/ {print int($1)}'`
    lib_hrx=`echo "$result" | awk '/^[0-9\. \t]+$/ {print $1}'`

    if [ $buf_hr -le ${5} -o $lib_hr -le ${5} ] ; then
  	echo "${2} CRITICAL - Cache Hit Rates: $lib_hrx% Lib -- $buf_hrx% Buff|lib=$lib_hrx%;${6};${5};0;100 buffer=$buf_hrx%;${6};${5};0;100"
	exit $STATE_CRITICAL
    fi
    if [ $buf_hr -le ${6} -o $lib_hr -le ${6} ] ; then
  	echo "${2} WARNING  - Cache Hit Rates: $lib_hrx% Lib -- $buf_hrx% Buff|lib=$lib_hrx%;${6};${5};0;100 buffer=$buf_hrx%;${6};${5};0;100"
	exit $STATE_WARNING
    fi
    echo "${2} OK - Cache Hit Rates: $lib_hrx% Lib -- $buf_hrx% Buff|lib=$lib_hrx%;${6};${5};0;100 buffer=$buf_hrx%;${6};${5};0;100"

    exit $STATE_OK
    ;;
--tablespace)
    if [ ${6} -lt ${7} ] ; then
	echo "UNKNOWN - Warning level is more then Crit"
	exit $STATE_UNKNOWN
    fi
    result=`sqlplus -s ${3}/${4}@${2} << EOF
set pagesize 0;
set numf '099999999D990'
-- set numf '99999999.99'
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
#    echo "Free = $ts_free, Total = $ts_total, PCT = $ts_pct, PCTX = $ts_pctx"
    
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

--tablesize)
    if [ ${6} -lt ${7} ] ; then
	echo "UNKNOWN - Warning should be lesser than Critical"
	exit $STATE_UNKNOWN
    fi

result=`sqlplus -s ${3}/${4}@${2} << EOF
set pagesize 0;
set numf '099999999D990'
select
sum(bytes)/(1024*1024) table_size_meg
from user_extents
where segment_type='TABLE'
and segment_name = '${5}';
EOF`

    if [ -n "`echo $result | grep 'no rows selected'`" ] ; then
	error="UNKNOWN - Table ${5} not found (no rows selected)"
	echo $error
	exit $STATE_UNKNOWN
    fi


    if [ -n "`echo $result | grep ORA-`" ] ; then
      error=` echo "$result" | grep "ORA-" | head -1`
      echo "CRITICAL - $error"
      exit $STATE_CRITICAL
    fi

#    echo $result

    result1=`echo $result | sed -e 's/^[ \t]*//' | awk '/[0-9\.]+/ {printf "%d",$1}'`
#    echo $result1

    if [ "$result1" -ge ${6} ] ; then
	echo "CRITICAL - Table ${5} current space is ${result1}MB | ${5}=${result1}MB;${7};${6};0;100 [check_oracle.sh]"
	exit $STATE_CRITICAL
    fi

    if [ "$result1" -ge ${7} ] ; then
	echo "WARNING - Table ${5} current space is ${result1}MB | ${5}=${result1}MB;${7};${6};0;100 [check_oracle.sh]"
	exit $STATE_WARNING
    fi

    echo "OK - Table ${5} current space is ${result1}MB | ${5}=${result1}MB;${7};${6};0;100 [check_oracle.sh]"
    exit $STATE_OK
    ;;


--prints)
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
#echo $result
    if [ -n "`echo $result | grep ORA-`" ] ; then
      error=` echo "$result" | grep "ORA-" | head -1`
      echo "CRITICAL - $error"
      exit $STATE_CRITICAL
    fi

    result1=`echo $result | sed --posix -r 's/^([A-Za-z0-9\_]*)\s([0-9\.]*)\s([0-9\.]*)\s([0-9\.]*)\s([0-9\.]*)\s[a-zA-Z0-9\.]*\s[0-9\.]*\s[a-zA-Z]*\s[a-zA-Z]*\s[a-zA-Z]*$/\2 \4 \5/' | awk ' {if ($0 ~ /[a-zA-Z]+/) print "0 0 0"; else print $0}'`
    pr_total=`echo "$result1" | awk '/[0-9\.]+/ {printf "%d",$1}'` 
    pr_broken=`echo "$result1" | awk '/[0-9\.]+/ {printf "%d",$2}'` 
    pr_queue=`echo "$result1" | awk '/[0-9\.]+/ {printf "%d",$3}'` 
    #ts_pctx=`echo "$result1" | awk '/[0-9\.]+/ {printf "%.2f",$2}'`
#    echo "All = $pr_total, Broken = $pr_broken, In queue = $pr_queue"
    
    if [ "$pr_broken" -eq ${5} ] ; then
  	echo "WARNING - Prints with error: $pr_broken, Prints in queue: $pr_queue|Total=$pr_total;;;; Broken=$pr_broken;;;; Queued=$pr_queue;;;;"
	exit $STATE_WARNING
    fi
    if [ "$pr_broken" -gt ${5} ] ; then
  	echo "CRITICAL - Prints with error: $pr_broken, Prints in queue: $pr_queue, Total: $pr_total|Total=$pr_total;;;; Broken=$pr_broken;;;; Queued=$pr_queue;;;;"
	exit $STATE_CRITICAL
    fi
    if [ "$pr_queue" -ge ${6} ] ; then
  	echo "WARNING  - Too many prints in queue. Total: $pr_total, Queue: $pr_queue|Total=$pr_total;;;; Broken=$pr_broken;;;; Queued=$pr_queue;;;;"
	exit $STATE_WARNING
    fi

    echo "OK - Total: $pr_total, Errors: $pr_broken, Queued: $pr_queue|Total=$pr_total;;;; Broken=$pr_broken;;;; Queued=$pr_queue;;;;"
    exit $STATE_OK
    ;;

--batchjobs)
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
#echo $result
    if [ -n "`echo $result | grep ORA-`" ] ; then
      error=` echo "$result" | grep "ORA-" | head -1`
      echo "CRITICAL - $error"
      exit $STATE_CRITICAL
    fi

    result1=`echo $result | sed --posix -r 's/^([A-Za-z0-9\_]*)\s([0-9\.]*)\s([0-9\.]*)\s([0-9\.]*)\s([0-9\.]*)\s[a-zA-Z0-9\.]*\s[0-9\.]*\s[a-zA-Z]*\s[a-zA-Z]*\s[a-zA-Z]*$/\2 \4 \5/' | awk ' {if ($0 ~ /[a-zA-Z]+/) print "0 0 0"; else print $0}'`
    bat_total=`echo "$result1" | awk '/[0-9\.]+/ {printf "%d",$1}'` 
    bat_broken=`echo "$result1" | awk '/[0-9\.]+/ {printf "%d",$2}'` 
    bat_queue=`echo "$result1" | awk '/[0-9\.]+/ {printf "%d",$3}'` 
    #ts_pctx=`echo "$result1" | awk '/[0-9\.]+/ {printf "%.2f",$2}'`
#    echo "All = $pr_total, Broken = $pr_broken, In queue = $pr_queue"
    
    if [ "$bat_broken" -eq ${5} ] ; then
  	echo "WARNING - Batch jobs with error: $bat_broken, Batch jobs in queue: $bat_queue|Total=$bat_total;;;; Broken=$bat_broken;;;; Queued=$bat_queue;;;;"
	exit $STATE_WARNING
    fi
    if [ "$bat_broken" -gt ${5} ] ; then
  	echo "CRITICAL - Batch jobs with error: $bat_broken, Batch jobs in queue: $bat_queue, Total: $bat_total|Total=$bat_total;;;; Broken=$bat_broken;;;; Queued=$bat_queue;;;;"
	exit $STATE_CRITICAL
    fi
    if [ "$bat_queue" -ge ${6} ] ; then
  	echo "WARNING  - Too many batch jobs in queue. Total: $bat_total, Queue: $bat_queue|Total=$bat_total;;;; Broken=$bat_broken;;;; Queued=$bat_queue;;;;"
	exit $STATE_WARNING
    fi

    echo "OK - Total: $bat_total, Errors: $bat_broken, Queued: $bat_queue|Total=$bat_total;;;; Broken=$bat_broken;;;; Queued=$bat_queue;;;;"
    exit $STATE_OK
    ;;

--batches)
    result=`sqlplus -s ${3}/${4}@${2} << EOF
set pagesize 0;
select name, job from demon_control
where session_id not in (select audsid from v\\$session);
EOF`

# Original request:
# set pagesize 0;
# select name, job from demon_control
# where session_id not in (select audsid from v\\$session);

# Check without specific batch
#select dc.name, dc.job from demon_control dc, v\\$instance i
#where (upper(i.instance_name) = 'BETRIPRD'
#and dc.name != 'B8623' 
#and dc.session_id not in (select audsid from v\\$session))
#or (upper(i.instance_name)='TFPROD'
#and dc.session_id not in (select audsid from v\\$session));



#echo $result

    if [ -n "`echo $result | grep ORA-`" ] ; then
      error=` echo "$result" | grep "ORA-" | head -1`
      echo "CRITICAL - $error"
      exit $STATE_CRITICAL
    fi

    if [ -n "`echo $result | grep 'no rows selected'`" ] ; then
	error="OK - All batches up."
	echo $error
	exit $STATE_OK
    fi


    result1=`echo $result | sed -e 's/[0-9]* rows selected.//g' | sed --posix -r 's/([A-Z][0-9]{4})\s([0-9])/\1(Job \2)/g'  | awk '{ print $0 }'`
    #echo "Dupa: $result1"
    bacz_down=`echo "$result1"`

    echo "CRITICAL - Following batch(es) is/are DOWN on ${2}: $bacz_down"
    exit $STATE_CRITICAL
    ;;

--asm)
    result=`sqlplus -s ${3}/${4}@${2} << EOF
set pagesize 0;
select name, total_mb, free_mb from v\\$asm_diskgroup
where name='${5}';
EOF`

#echo $result

    if [ -n "`echo $result | grep ORA-`" ] ; then
      error=` echo "$result" | grep "ORA-" | head -1`
      echo "CRITICAL - $error"
      exit $STATE_CRITICAL
    fi

    if [ -n "`echo $result | grep 'no rows selected'`" ] ; then
	error="CRITICAL - Where is ASM? (Wrong diskgroup name?)"
	echo $error
	exit $STATE_CRITICAL
    fi

    result1=`echo $result | sed -e 's/[0-9]* rows selected.//g' | sed --posix -r 's/([A-Za-z\_]+)\s([0-9]+)\s([0-9]+)$/\2 \3/g' | awk '{ print $0 }'`

    asm_total=`echo "$result1" | awk '/[0-9]+/ {printf "%d",$1}'`
    asm_free=`echo "$result1" | awk '/[0-9]+/ {printf "%d",$2}'`
#    echo "Total: $asm_total, Free: $asm_free"
    
    if [ "$asm_free" -lt ${7} ] ; then
  	echo "CRITICAL - Low disk space on ${5}! $asm_free MB/$asm_total MB|${5}=${asm_free}MB;${6};${7};0;${asm_total}"
	exit $STATE_CRITICAL
    fi
    if [ "$asm_free" -lt ${6} ] ; then
  	echo "WARNING - Low disk space on ${5}! $asm_free MB/$asm_total MB|${5}=${asm_free}MB;${6};${7};0;${asm_total}"
	exit $STATE_WARNING
    fi

    echo "OK - Free space on ${5}: $asm_free MB/$asm_total MB|${5}=${asm_free}MB;${6};${7};0;${asm_total}"
    exit $STATE_OK
    ;;

--usersession)
    result=`sqlplus -s ${3}/${4}@${2} << EOF
set pagesize 0;
select count(sid) from v\\$session
where upper(program)='FRMWEB.EXE';
EOF`

#echo $result

    if [ -n "`echo $result | grep ORA-`" ] ; then
      error=` echo "$result" | grep "ORA-" | head -1`
      echo "CRITICAL - $error"
      exit $STATE_CRITICAL
    fi

    if [ -n "`echo $result | grep 'no rows selected'`" ] ; then
	error="CRITICAL - No user sessions? Something is wrong!"
	echo $error
	exit $STATE_CRITICAL
    fi

    sid_total=`echo "$result" | awk '/[0-9]+/ {printf "%d",$1}'`
    #echo "Total: $sid_total"
    
    echo "OK - User sessions on ${2}: $sid_total|${2} sessions number=${sid_total};;;;"
    exit $STATE_OK
    ;;

--pcm)
    result=`sqlplus -s ${3}/${4}@${2} << EOF
set pagesize 0;
select count(eventstatus) from PCM_EVENT where
eventstatus='Unhandled'
and TIMESTAMP between trunc(sysdate) and trunc(sysdate)+1;
EOF`

#echo $result

    if [ -n "`echo $result | grep ORA-`" ] ; then
      error=` echo "$result" | grep "ORA-" | head -1`
      echo "CRITICAL - $error"
      exit $STATE_CRITICAL
    fi

    events_num=`echo "$result" | awk '/[0-9]+/ {printf "%d",$1}'`
    #echo "Total: $events_num"
    
    if [ $events_num -eq "0" ]; then
	echo "OK - No unhandled events"
	exit $STATE_OK
    else
	echo "CRITICAL - Unhandled events: $events_num"
        exit $STATE_CRITICAL
    fi
    ;;

*)
    print_usage
		exit $STATE_UNKNOWN
esac

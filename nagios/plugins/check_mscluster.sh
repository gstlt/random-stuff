#!/bin/bash
# Monitoring services of two servers using check_nt for cluster
# 2008 Grzegorz 'gstlt' Adamowicz
# http://gstlt.info

# Where the plugin resides:
PLUGIN='/usr/lib/nagios/plugins/check_nt'

# Handling two hosts
# You should pass them to plugin like: -H host1.domain.com,host2.domain.com
HOST1=`echo $@ | sed -r --posix 's/([A-Za-z\-]+)\s([0-9A-Za-z\.\-]+),([0-9A-Za-z\.\-]+)/\1 \2/g'`
HOST2=`echo $@ | sed -r --posix 's/([A-Za-z\-]+)\s([0-9A-Za-z\.\-]+),([0-9A-Za-z\.\-]+)/\1 \3/g'`

# Executing plugin and collecting return codes
RET_STRING_H1=`$PLUGIN $HOST1`
RET_HOST1=$?
#echo "HOST1 $RET_HOST1"

RET_STRING_H2=`$PLUGIN $HOST2`
RET_HOST2=$?
#echo "HOST2 $RET_HOST2"

# Checking states and exit with appropriate return code. (Assuming
# host1 primary)
if [ $RET_HOST1 -gt "0" ]; then
    if [ $RET_HOST2 -gt "0" ]; then
	if [ $RET_HOST1 -gt $RET_HOST2 ]; then
	    echo $RET_STRING_H1
	    exit $RET_HOST1
	else
	    echo $RET_STRING_H2
	    exit $RET_HOST2
	fi
    else
	echo $RET_STRING_H2
	exit $RET_HOST2
    fi
else
    echo $RET_STRING_H1
    exit $RET_HOST1
fi

echo "UNKNOWN - I don't know what is going on!!"
exit 3

#!/bin/bash
# (c) 2011 NCDC, Grzegorz Adamowicz
# This script uses the_utils.sh script to run correctly. ncdc_utils should have come with
# check_asusers.ncdc script. If you can't find it, contact us.
#
# Contact us if you have any questions/suggestions regarding this script at sys-tech@ncdc.pl
#
# Curl and perl is required to run this script.

PROGNAME=`basename $0`
REVISION="0.5"
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`

if [ -x $PROGPATH/the_utils.sh ]; then
        . $PROGPATH/the_utils.sh
fi

print_usage() {
	echo "Usage: $0 <user> <pass> <url>"
	echo ""
}

print_help() {
	print_usage
	echo ""
	echo "<user>			user name to access Enterprise Manager, usually ias_admin"
	echo "<pass>			for user to access Enterprise Manager"
	echo "<url>				URL must point to a Forms tab inside Enterprise Manager"
	echo "					Forms tab shows current \"User Sessions\" running forms application"
	echo ""
	echo "					Example:"
	echo "					http://server.local:18100/emd/console/forms/forms?ctxName1=ias_admin.server&type=oracle_forms&target=ias_admin.server_Forms&ctxType1=oracle_ias"
}

case "$1" in
--help)
	print_help
   	exit $STATE_OK
    ;;
-h)
	print_help
    exit $STATE_OK
    ;;
-?)
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



if [ ! -n "$1" ]; then
	echo "ERROR: USER argument missing! Enter '$0 -h' to see help"
	exit $STATE_UNKNOWN
elif [ ! -n "$2" ]; then
	echo "ERROR: PASS argument missing! Enter '$0 -h' to see help"
	exit $STATE_UNKNOWN
elif [ ! -n "$3" ]; then
	echo "ERROR: URL argument missing! Enter '$0 -h' to see help"
	exit $STATE_UNKNOWN
fi

USER=$1
PASS=$2
URL=$3

# prepare url (PERL POWER!)
CURLURL=`echo $URL $USER:$PASS | perl -wpe 's/(http:\/\/)(.*)\s(.*):(.*)$/http:\/\/$3:$4\@$2/g'`

OUTPUT=`curl -H "Accept-Language: en-us" -s $CURLURL | perl -wpe 's/(.*)User Sessions\<\/span\>\<\/td\>\<td width=\"12\"\>\<img src=\"\/cabo\/images\/t\.gif\" width=\"12\" height=\"0\"\>\<\/td\>\<td width=\"0\" align=\"left\"\>\<span class=\"x2\"\>(\d+)(.*)/$2/g' | perl -wpe 's/^\s+|\s+$//g'`

# Debug?
#echo $OUTPUT
#echo ""

# Check if we've authorized ourselves
if [ "$(echo "$OUTPUT" | perl -wpe 's/(.*)\<TITLE\>(.*)\<\/TITLE\>(.*)/$2/')" = "401 Unauthorized" ]; then
	echo "ERROR: Unauthorized! Wrong username or password"
	exit $STATE_CRITICAT
fi

# Check if EM is not throwing 500 on us (THIS IS ORACLE!!!)
if [ "$(echo "$OUTPUT" | perl -wpe 's/(.*)\<TITLE\>(.*)\<\/TITLE\>(.*)/$2/')" = "500 Internal Server Error" ]; then
	echo "ERROR: Internal Server Error - check Enterprise Manager and passed URL"
	exit $STATE_CRITICAT
fi

# Check if number of users is a number :-)
if [ ! $(echo "$OUTPUT" | grep -E "^[0-9]+$") ]; then
	echo "ERROR: User sesssions not found. Wrong URL?"
	exit $STATE_UNKNOWN
fi

echo "OK: User Sessions: $OUTPUT|users=$OUTPUT;999;1000;0;0"
exit $STATE_OK

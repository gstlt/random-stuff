## Tools for Windows NRPE plugin (works with NSClient++)

These are basically a set of cmd scripts to check DNS and LDAP (Active Directory) from Windows machine.

I've used it to make sure that LDAP is available from one Windows machine to the other. It has been used along with other tests on Nagios host so these were just additional checks.

## Overview

### check_dns.cmd

Checks if hosts in network can be resolved using ping and nslookup utilities.

First it is sending one ping request, after response from server, it's executing nslookup on given host.

### check_dns_time.cmd

Does the same thing as script above but additionally it's counting how much time it took to run script.


### check_ldap.cmd

This script is using queryad.vbs (included) script from MS Resource Kit Tools to query LDAP (Active Directory) for username Firstname and Lastname.

When found, returns success, otherwise returns error (CRITICAL in Nagios terms).

You need to edit check_ldap.cmd to match location of queryad.vbs script in your system (default: C:\scripts\ldap\queryad.vbs).

Note that script will not work correctly if there are spaced in folder names.

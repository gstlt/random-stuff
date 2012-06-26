## MySQL collect plugin

It's not a plugin per se, it's a perl script runned by Collectd exec plugin.

## How to set it up?

You have sample collectd.conf file how to configure your Collect daemon.

You need to change user/pass for MySQL access within mysql-collectd.pl script.

Next, edit query CSV file (read comments inside CSV file).

It's possible you'll need to add new types for your Collectd installation - see types_sample.db

Let me know if you need assistance.
#!/usr/bin/perl

use strict;
use warnings;
use Text::CSV;
use Net::Domain qw(hostname hostfqdn hostdomain domainname);
use DBI;

my $csv = Text::CSV->new();
my ($user, $pass) = ("mysqluser", "mysqlpass");  # User and password to mysql database (root to access all desired databases)
my $sql = "/opt/collectd/scripts/query.csv";# File where you can define your queries
my $hostname = hostfqdn();          # My hostname (FQDN)
my $interval = 10;                  # Sleep interval
my @lines;                          # Parsed clean csv file
my $csvline;                        # One line from CSV file


open (CSV, "<", $sql) or die $!;
# Remove empty lines
foreach(<CSV>) {
	# Remove all comments
	$_ =~ s/(^#.*)|(#.*$)|(\s+#.*$)//;
	push @lines,$_ unless ($_ eq "\n");
}

close(CSV);

# Sort in alphabetical order and remove new lines
@lines = sort(@lines);
chomp(@lines);

while (1) {
	foreach $csvline (@lines) {
		if ($csv->parse($csvline)) {
			my @column = $csv->fields();
			my $time = time;

			#print "Database: $column[0]  Check name: $column[1]   Query: $column[2]\n";
			my @result = conquer($column[0], $user, $pass, $column[2]);
			my $values = parse_result(@result);
			#print "Result in_main: $values\n";
			print "PUTVAL $hostname/db$column[0]/$column[1] interval=$interval $time$values\n";


		} else {
			print "$sql: Error: $csv->error_input()\n";
			exit 1;
		}

	}
	sleep $interval;
}


# connect and execute query
# TODO rewrite to make one connection per query for a database and reconnect if query is for another database (is that make sense?)
sub conquer {
	my $database = shift;
	my $user = shift;
	my $password = shift;
	my $query = shift;
	my $q;
	my @return;

	my $dbh = DBI->connect("DBI:mysql:$database", $user, $pass) || die "Could not connect to database: $DBI::errstr";
	$q = $dbh->prepare("$query");
	#print "Query in_conquer: $query\n";
	$q->execute();

	while (my @result = $q->fetchrow_array) {
		#print "Result in_conquer: @result\n";
		foreach my $tmp (@result) {
			push @return,$tmp;
		}
	}
#	$q->finish();
	$dbh->disconnect();

	return @return;
}


# parse query and return results to STDOUT with appropriate formatting
sub parse_result {
	my @values = @_;
	my $value;
	my $return = "";

	foreach $value (@values) {
		#print "Parser all_values: @values\n";
		#print "Parser: $value\n";
		$return = $return.":".$value;
	}

	return $return;
}

#!/usr/bin/env perl

=head1 NAME

metadata_features.pl - list features available for a search

=head1 SYNOPSIS

metadata_features.pl [options] --target TEXT1 --source TEXT2

=head1 DESCRIPTION

Return a list of all the features indexed for both I<TEXT1> and I<TEXT2>.

=head1 OPTIONS AND ARGUMENTS

=over

=item I<TEXT1>, I<TEXT2>

The texts to check.

=item B<--help>

Print usage and exit.

=back

=head1 KNOWN BUGS

=head1 SEE ALSO

=head1 COPYRIGHT

University at Buffalo Public License Version 1.0.
The contents of this file are subject to the University at Buffalo Public License Version 1.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://tesserae.caset.buffalo.edu/license.txt.

Software distributed under the License is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for the specific language governing rights and limitations under the License.

The Original Code is metadata_features.pl.

The Initial Developer of the Original Code is Research Foundation of State University of New York, on behalf of University at Buffalo.

Portions created by the Initial Developer are Copyright (C) 2007 Research Foundation of State University of New York, on behalf of University at Buffalo. All Rights Reserved.

Contributor(s): Chris Forstall

Alternatively, the contents of this file may be used under the terms of either the GNU General Public License Version 2 (the "GPL"), or the GNU Lesser General Public License Version 2.1 (the "LGPL"), in which case the provisions of the GPL or the LGPL are applicable instead of those above. If you wish to allow use of your version of this file only under the terms of either the GPL or the LGPL, and not to allow others to use your version of this file under the terms of the UBPL, indicate your decision by deleting the provisions above and replace them with the notice and other provisions required by the GPL or the LGPL. If you do not delete the provisions above, a recipient may use your version of this file under the terms of any one of the UBPL, the GPL or the LGPL.

=cut

use strict;
use warnings;

#
# Read configuration file
#

# modules necessary to read config file

use Cwd qw/abs_path/;
use File::Spec::Functions;
use FindBin qw/$Bin/;

# read config before executing anything else

my $lib;

BEGIN {

	# look for configuration file
	
	$lib = $Bin;
	
	my $oldlib = $lib;
	
	my $pointer;
			
	while (1) {

		$pointer = catfile($lib, '.tesserae.conf');
	
		if (-r $pointer) {
		
			open (FH, $pointer) or die "can't open $pointer: $!";
			
			$lib = <FH>;
			
			chomp $lib;
			
			last;
		}
									
		$lib = abs_path(catdir($lib, '..'));
		
		if (-d $lib and $lib ne $oldlib) {
		
			$oldlib = $lib;			
			
			next;
		}
		
		die "can't find .tesserae.conf!\n";
	}
	
	$lib = catdir($lib, 'TessPerl');
}

# load Tesserae-specific modules

use lib $lib;
use Tesserae;
use EasyProgressBar;

# modules to read cmd-line options and print usage

use Getopt::Long;
use Pod::Usage;

# load additional modules necessary for this script

use CGI qw/:standard/;
use JSON;
use Data::Dumper;

# initialize some variables

my $help = 0;
my $name;

# is the program being run from the web or
# from the command line?

my $query = CGI->new() || die "$!";

my $no_cgi = defined($query->request_method()) ? 0 : 1;

# print debugging messages to stderr?

my $quiet = 0;
my $target;
my $source;

#
# check web, cli for query args
#

if ($no_cgi) {
	# get cli query args

	GetOptions(
		'help'  => \$help,
		'quiet' => \$quiet,
		'target=s' => \$target,
		'source=s' => \$source
	);
	
	# print usage if the user needs help
	
	if ($help) {

		pod2usage(1);
	}
}
else {
	print header(-type => 'text/plain');

	# get web-based query args
	
	$target = $query->param('target');
	$source = $query->param('source');

	$quiet = 1;
}


my @features;

if ($target and $source) {
		
	my $dbh = Tesserae::metadata_dbh;

	my $sql = "select * from texts where name=\"$target\" or name=\"$source\";";
	print STDERR "sql='$sql'\n" unless $quiet;

	my $sth = $dbh->prepare($sql);
	$sth->execute;

	my %count;

	my $min = ($target eq $source ? 1 : 2);

	while (my $res = $sth->fetchrow_hashref) {
		for my $col (grep {/^feat_/} keys %$res) {
			my $feat = $col;
			$feat =~ s/feat_//;
			$count{$feat} += $res->{$col};
		}
	}

	@features = grep { $count{$_} >= $min } keys %count;
	@features = map {{name=>$_, display=>($Tesserae::feature_display{$_} or $_)}} sort @features;
}


#
# print results
#

{
	print encode_json(\@features) if @features;
	print "\n";
}




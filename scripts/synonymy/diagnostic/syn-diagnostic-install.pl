#!/usr/bin/env perl

=head1 NAME

syn-diagnostic-install.pl - install trans dictionary in diagnostic interface

=head1 SYNOPSIS

syn-diagnostic-install.pl [--feature NAME] DICT

=head1 DESCRIPTION

Reads one or more translation/synonymy dictionaries in CSV format; creates
and installs a SQLite database of the results that will be used by the syn-
diagnostic interface. Dictionaries to be installed should have the same 
characteristics as those used with F<scripts/synonymy/build-trans-cache.pl>.
In fact, they ought to be the same ones, and given the same feature names,
otherwise the dignostic tool won't be very helpful.

=head1 OPTIONS AND ARGUMENTS

=over

=item I<DICT>

Translation dictionary to read, in CSV format. 
See F<scripts/synonymy/build-trans-cache.pl> for details.

=item B<--feature> NAME

Optional name for feature set. Default is "trans".

=item B<--help>

Print usage and exit.

=back

=head1 KNOWN BUGS

=head1 SEE ALSO

=head1 COPYRIGHT

University at Buffalo Public License Version 1.0. The contents of this file
are subject to the University at Buffalo Public License Version 1.0 (the
"License"); you may not use this file except in compliance with the License.
You may obtain a copy of the License at
http://tesserae.caset.buffalo.edu/license.txt.

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is syn-diagnostic-install.pl.

The Initial Developer of the Original Code is Research Foundation of State
University of New York, on behalf of University at Buffalo.

Portions created by the Initial Developer are Copyright (C) 2007 Research
Foundation of State University of New York, on behalf of University at
Buffalo. All Rights Reserved.

Contributor(s): Chris Forstall <cforstall@gmail.com>, James Gawley

Alternatively, the contents of this file may be used under the terms of
either the GNU General Public License Version 2 (the "GPL"), or the GNU
Lesser General Public License Version 2.1 (the "LGPL"), in which case the
provisions of the GPL or the LGPL are applicable instead of those above. If
you wish to allow use of your version of this file only under the terms of
either the GPL or the LGPL, and not to allow others to use your version of
this file under the terms of the UBPL, indicate your decision by deleting the
provisions above and replace them with the notice and other provisions
required by the GPL or the LGPL. If you do not delete the provisions above, a
recipient may use your version of this file under the terms of any one of the
UBPL, the GPL or the LGPL.

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
use SynDiagnostic;
use EasyProgressBar;

# modules to read cmd-line options and print usage

use Getopt::Long;
use Pod::Usage;

# load additional modules necessary for this script

use DBI;
use Encode;

# initialize some variables

my $feat = "trans";
my $file_dict;
my $help;
my $quiet;
my $clean = 1;
my %file;

# table definitions for feature databases

my $table_def = [
   [query => "varchar(80)"],
   [result => "varchar(80)"],
   [score => "real"]
];

# get user options

GetOptions(
	'feature=s'   => \$feat,
	'help'        => \$help,
   'clobber!'    => \$clean,
	'quiet'       => \$quiet
);

# print usage if the user needs help
	
if ($help) {
	pod2usage(1);
}

$file_dict = shift @ARGV;
unless ($file_dict and -s $file_dict) {
   pod2usage(2);
}

binmode STDOUT, ':utf8';

#
# parse the csv dictionary
#

my $ref_results = parse_dict($file_dict);

#
# connect to syn-diagnostic database
#

my $file_db = catfile($fs{data}, "synonymy", "dict-diagnostic", "syn-diagnostic.db");
my $dbh = SynDiagnostic::db_connect($file_db);

# check tables exist

if (SynDiagnostic::check_table($dbh, "feat_$feat")) {
   if ($clean) {
      print STDERR "Clobbering existing table in database\n" unless $quiet;
      $dbh->do("drop table feat_$feat");
   }
   else {
      die "Feat $feat already exists in database.";
   }
}
SynDiagnostic::create_table($dbh, "feat_$feat", $table_def);


# populate results table
populate_results($dbh, $ref_results);

#
# subroutines
#

sub parse_dict {
   # read the CSV dictionary
   # presumed record format is query,res1[:score],res2[:score],...\n
   
   my $file = shift;
   my %result;
   
	open (my $fh, '<:utf8', $file) or die "Can't read $file: $!";

	print STDERR "Parsing $file\n" unless $quiet;

	my $pr = ProgressBar->new(-s $file, $quiet);

	while (my $line = <$fh>) {
		$pr->advance(length(Encode::encode('utf8', $line)));

		chomp $line;

		my ($query, @res) = split(/\s*,\s*/, $line);

		$query = Tesserae::standardize(SynDiagnostic::lang($query), $query);
		
      for my $r (@res) {
         $r =~ s/:([-\.0-9]+)$//;
         my $score = ($1 or 1);
         $r = Tesserae::standardize(SynDiagnostic::lang($r), $r);
         $r =~ s/\s//g;
         
         if ($r =~ /\S/) {
            $result{$query}{$r} = $score;
         }
      }
	}

   close $fh;
   
   return \%result;
}

sub populate_results {
   # populate the results table
   #  - I learned a lot about speeding this up from
   #    http://www.perlmonks.org/?node_id=273952
   
   my ($dbh, $ref_result) = @_;
   my %result = %$ref_result;
   
   my $max_commit = 5000;
   
   print STDERR "Writing table feat_$feat to db.\n" unless $quiet;
   
   my $pr = ProgressBar->new(scalar(keys %result), $quiet);

   my $sth = $dbh->prepare(
      qq{insert into feat_$feat values (?, ?, ?)}
   );
   
   $dbh->do("begin");
   my $inserted = 0;

   for my $query (keys %result) {
      for my $res (keys %{$result{$query}}) {
         my $score = $result{$query}{$res};
         
         $inserted += $sth->execute($query, $res, $score);
         
         if ($inserted % $max_commit == 0) {
            $dbh->do("commit");
            $dbh->do("begin");
         }
      }
      $pr->advance;
   }
   $dbh->do("commit");
}

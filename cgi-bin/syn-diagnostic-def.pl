#!/usr/bin/env perl

=head1 NAME

syn-diagnostic-def.pl - look up a headword in the lexicon

=head1 SYNOPSIS

syn-diagnostic-def.pl [options] QUERY

=head1 DESCRIPTION

A more complete description of what this script does. Normally meant to serve
AJAX requests from the syn-diagnostic interface.

=head1 OPTIONS AND ARGUMENTS

=over

=item I<QUERY>

The term to be looked up.

=item B<--html>

Print the same HTML output that would be sent to a web user.

=item B<--help>

Print usage and exit.

=back

=head1 KNOWN BUGS

=head1 SEE ALSO

=head1 COPYRIGHT

University at Buffalo Public License Version 1.0.
The contents of this file are subject to the University at Buffalo Public License Version 1.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://tesserae.caset.buffalo.edu/license.txt.

Software distributed under the License is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for the specific language governing rights and limitations under the License.

The Original Code is syn-diagnostic-def.pl.

The Initial Developer of the Original Code is Research Foundation of State University of New York, on behalf of University at Buffalo.

Portions created by the Initial Developer are Copyright (C) 2007 Research Foundation of State University of New York, on behalf of University at Buffalo. All Rights Reserved.

Contributor(s): Chris Forstall <cforstall@gmail.com>

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
use Storable;
use utf8;
use Encode;

binmode STDOUT, 'utf8';
binmode STDERR, 'utf8';

# initialize some variables

my $query;
my $lang;
my $html;
my $help;
my $quiet;

#
# check for cgi interface
#

my $cgi = CGI->new() || die "$!";
my $no_cgi = defined($cgi->request_method()) ? 0 : 1;

#
# get user options
#

if ($no_cgi) {
	
	GetOptions(
		'help'    => \$help,
      'quiet'   => \$quiet,
      'lang=s'  => \$lang,
		'html'    => \$html
	);
	
	# print usage if the user needs help

	if ($help) {
		pod2usage(1);
	}
   
   $query = shift @ARGV;
   
   unless ($query) {
      pod2usage(1);
   }
} else {
		
	print header('-charset'=>'utf-8', '-type'=>'text/plain');

	$query = $cgi->param('query');
	$html = 1;
   $quiet = 1;
}

$query = decode("utf8", $query);
unless ($lang) {
   $lang = is_greek($query) ? "grc" : "la";
}
$query = Tesserae::standardize($lang, $query);

print STDERR "$query:\n" unless $quiet;

print load_def($query);

#
# subroutines
#

sub load_def {
   # retrieve definition for a word
   
	my $query = shift;
	
	my $def = "";
	
	if (defined $query and $query ne "") {

		my $file = catfile($fs{data}, "synonymy", "dict-diagnostic", substr($query, 0, 1)); 

		if (-s $file) {
		
			if (open (my $fh, "<:utf8", $file)) {
			
				while (my $rec = <$fh>) {
					
					my ($head, $def_) = split(/::/, $rec);
					
					my $lang = is_greek($head) ? "grc" : "la";
					
					$head = Tesserae::standardize($lang, $head);
					
 					if ($head eq $query) {
					
						$def = $def_;
					
						last;
					}
				}
			}
		}
	}

	return $def;
}


#
# guess whether a word is greek
#

sub is_greek {

	my $token = shift;
	
	my @c = split(//, $token);
	
	for (@c) {
		
		if (ord($_) > 255) {

			return 1;
		}
	}
	
	return 0;
}

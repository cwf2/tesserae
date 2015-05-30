#!/usr/bin/env perl

=head1 NAME

transliterate.pl - create a greek-latin transliteration dictionary

=head1 SYNOPSIS

transliterate.pl [options]

=head1 DESCRIPTION

Look for correspondences between the Greek stem list and the Latin list
based on simple transliteration rules. Print out a list of these that
can be used as a supplement to the translation dictionary.

=head1 OPTIONS AND ARGUMENTS

=over

=item --grc I<FILE>
Greek stem list to use; default is for the full corpus 
(F<data/common/grc.stem.freq>).

=item --la I<FILE>
Latin stem list to use; default is for the full corpus 
(F<data/common/la.stem.freq>).

=item B<--help>

Print usage and exit.

=item B<--quiet>

Don't print debugging messages to stderr.

=back

=head1 KNOWN BUGS

=head1 SEE ALSO

=head1 COPYRIGHT

University at Buffalo Public License Version 1.0.
The contents of this file are subject to the University at Buffalo Public License Version 1.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://tesserae.caset.buffalo.edu/license.txt.

Software distributed under the License is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for the specific language governing rights and limitations under the License.

The Original Code is transliterate.pl.

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


# initialize some variables

my $help = 0;
my $quiet = 0;
my $file_grc = catfile($fs{data}, "common", "grc.stem.freq");
my $file_la = catfile($fs{data}, "common", "la.stem.freq");

# get user options

GetOptions(
    'grc=s' => \$file_grc,
    'la=s' => \$file_la,
	'help' => \$help,
    'quiet' => \$quiet
);

# print usage if the user needs help
if ($help) {

	pod2usage(1);
}

my @greek = @{Tesserae::stoplist_array($file_grc)};
my @latin = @{Tesserae::stoplist_array($file_la)};

#
# subroutines
#
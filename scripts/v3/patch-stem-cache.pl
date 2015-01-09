#!/usr/bin/env perl

=head1 NAME

patch-stem-cache.pl - patch dictionaries

=head1 SYNOPSIS

patch-stem-cache.pl

=head1 DESCRIPTION

Remove conflicts between edo and sum from the Latin dictionary.

=head1 OPTIONS AND ARGUMENTS

=head1 KNOWN BUGS

This is a hack and should be done away with if we can figure out a way to 
disambiguate lemmata better.

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

The Original Code is patch-stem-cache.pl.

The Initial Developer of the Original Code is Research Foundation of State
University of New York, on behalf of University at Buffalo.

Portions created by the Initial Developer are Copyright (C) 2007 Research
Foundation of State University of New York, on behalf of University at
Buffalo. All Rights Reserved.

Contributor(s): Chris Forstall <cforstall@gmail.com>

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
use EasyProgressBar;

# load additional modules necessary for this script

use Storable qw(nstore retrieve);
use Unicode::Normalize;
use utf8;

binmode STDERR, ':utf8';

#
# Latin: remove words that conflict with sum
#

{
	my $lang = 'la';

	my $file_cache = catfile($fs{data}, 'common', "$lang.stem.cache");

	my %stem = %{retrieve($file_cache)};

	print STDERR "removing stems which compete with \"sum\" from the stem dictionary\n";

	for (keys %stem) {

		if ( grep {/^sum$/} @{$stem{$_}}) {
	
			$stem{$_} = ['sum'];
		}
	}

	nstore \%stem, $file_cache;
}


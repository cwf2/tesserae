#!/usr/bin/env perl

=head1 NAME

part.pl - partition large texts

=head1 SYNOPSIS

part.pl [options] NAME

=head1 DESCRIPTION

Read a large file, partition into smaller textual units that a user
might want to search singly. NB: text must first have been indexed
using add_column.pl.

=head1 OPTIONS AND ARGUMENTS

=over

=item I<NAME>

The id of the text to partition.

=item B<--help>

Print usage and exit.

=back

=head1 KNOWN BUGS

=head1 SEE ALSO

=head1 COPYRIGHT

University at Buffalo Public License Version 1.0.
The contents of this file are subject to the University at Buffalo Public License Version 1.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://tesserae.caset.buffalo.edu/license.txt.

Software distributed under the License is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for the specific language governing rights and limitations under the License.

The Original Code is part.pl.

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

use DBI;
use Storable qw/nstore retrieve/;

# initialize some variables

my $help = 0;
my $quiet = 0;
my $prefix = "Book";

# get user options

GetOptions(
	"prefix=s" => \$prefix,
	"help"  => \$help
);


# print usage if the user needs help
	
if ($help) {

	pod2usage(1);
}


my $name = shift @ARGV;

my $base = Tesserae::get_base($name) or die "Invalid text";

my @unit = @{retrieve($base . ".line")};

my @chunk;
my $prev;

{
	my $loc = $unit[0]{LOCUS};
	my @components = split(/\./, $loc);
	$prev = $components[0];
	
	my @token_id = @{$unit[0]{TOKEN_ID}};
	
	push @chunk, {
		display => $prefix . " " . $components[0],
		loc => [$loc, $loc],
		token => [$token_id[0], $token_id[-1]]
	};
}

for my $unit_id (1..$#unit) {
	my $loc = $unit[$unit_id]{LOCUS};
	my @components = split(/\./, $loc);
	my @token_id = @{$unit[$unit_id]{TOKEN_ID}};
	
	if ($components[0] ne $prev) {
		push @chunk, {
			display => $prefix . " " . $components[0],
			loc => [$loc, $loc],
			token => [$token_id[0], $token_id[-1]]
		};
	}
	else {
		$chunk[-1]{loc}[-1] = $loc;
		$chunk[-1]{token}[-1] = $token_id[-1];		
	}
	
	$prev = $components[0];
}

for my $i (0..$#chunk) {
	
	print join("\t", 
		$chunk[$i]{display},
		join(":", @{$chunk[$i]{loc}}),
		join(":", @{$chunk[$i]{token}}),
		$chunk[$i]{token}[1] - $chunk[$i]{token}[0]
	);
	print "\n";
}


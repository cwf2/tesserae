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

use Storable qw/nstore retrieve/;
use XML::LibXML;

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


# get files to be processed from cmd line args

my @files = @ARGV;

unless (@files) {

	print STDERR "No files specified\n";
	pod2usage(2);
}

for my $file (@files) {	
	my $doc = eval{XML::LibXML->load_xml(location=>$file)};
	
	unless ($doc) {
		print STDERR "Can't read $file";
		print STDERR ": $@" if $@;
		print STDERR "\n";
	
		next;
	}

	my $root = $doc->documentElement;
	my $id = $root->getAttribute("id");
	
	my $body = $root->findnodes("Text");
	
	unless ($body->size == 1) {
		print STDERR "$file has " . $body->size . " text elements. Skipping.\n";
		next;
	}
	
	$body = $body->get_node(1);
	my $textchars = length($body->textContent);
	
	unless ($textchars > 25000) {
		print STDERR "$file is too short to partition. Skipping.\n";
		next;
	}
	
	my $textunits = $body->findnodes("TextUnit");
	
	unless ($textunits->size > 1) {
		print STDERR "$file doesn't have enough text units to partition. Skipping.\n";
		next;
	}

	my @chunk;
	my $prev;

	my $loc = $textunits->get_node(1)->getAttribute("loc");
	my @components = split(/\./, $loc);
	
	if ($#components == 0) {
		print STDERR "$file doesn't have major divisions. Skipping\n";
		next;
	}
	
	$prev = $components[0];

	my $unit_id = $textunits->get_node(1)->getAttribute("id");

	push @chunk, {
		Display => $prefix . " " . $components[0],
		Locus => [$loc, $loc],
		Unit => [$unit_id, $unit_id]
	};
	
	for my $unit ($textunits->get_nodelist) {
		my $loc = $unit->getAttribute("loc");
		my @components = split(/\./, $loc);
		my $unit_id = $unit->getAttribute("id");	
	
		if ($components[0] ne $prev) {
			push @chunk, {
				Display => $prefix . " " . $components[0],
				Locus => [$loc, $loc],
				Unit => [$unit_id, $unit_id]
			};
		}
		else {
			$chunk[-1]{Locus}[-1] = $loc;
			$chunk[-1]{Unit}[-1] = $unit_id;
		}
	
		$prev = $components[0];
	}
	
	if (scalar(@chunk) == 1) {
		print STDERR "$file only has one part. Skipping\n";
		next;
	}
	if (scalar(@chunk) > 30) {
		print STDERR "$file has too many divisions (" .scalar(@chunk) . "). Skipping\n";
		next;
	}
	if ($textchars/scalar(@chunk) < 10000) {
		print STDERR "$file has too few chars per part. Skipping.\n";
		next;
	}
	
	print STDERR "$file divided into " . scalar(@chunk) . " parts.";
	print STDERR sprintf(" Avg chars %.0f.\n", $textchars/scalar(@chunk));

	my $parts = $doc->createElement("Parts");
		
	for my $i (1..scalar(@chunk)) {
	
		my $part = $doc->createElement("Part");
		$part->setAttribute("id", $i);
		
		for my $e (
			[Display => $chunk[$i-1]{Display}],
			[MaskLower => $chunk[$i-1]{Unit}[0]],
			[MaskUpper => $chunk[$i-1]{Unit}[1]],
			[LocusLower => $chunk[$i-1]{Locus}[0]],
			[LocusUpper => $chunk[$i-1]{Locus}[1]] ) {
				
			my $element = $doc->createElement($e->[0]);
			$element->appendText($e->[1]);
			$part->appendChild($element);
		}

		$parts->appendChild($part);
	}

	$root->insertBefore($parts, $body);
	
	my $file_out = "texts/tmp/$id.xml";
	
	$doc->toFile($file_out, 2);
}


#!/usr/bin/env perl

#
# read_table.pl
#
# select two texts for comparison using the big table
#

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

use CGI qw(:standard);
use POSIX;
use Storable qw(nstore retrieve);

# allow unicode output

binmode STDOUT, ":utf8";

# is the program being run from the web or
# from the command line?

my $query = CGI->new() || die "$!";

my $no_cgi = defined($query->request_method()) ? 0 : 1;

#
# command-line options
#

# print debugging messages to stderr?

my $quiet = 0;

# determine file from session id

my $text_id;
my $part;
my $mask_upper;
my $mask_lower;
my $unit;

if ($no_cgi) {
	# command-line arguments

	GetOptions( 
		'source=s' => \$text_id,
		'part=i' => \$part,
		'mask_upper=i' => \$mask_upper,
		'mask_lower=i' => \$mask_lower,
		'unit=s' => \$unit,
		'quiet' => \$quiet
	);
} else {
	# cgi input

	print header();

	my $query = new CGI || die "$!";

	$text_id = $query->param("source");
	$unit = $query->param("unit");
	$part = $query->param("part");
	$mask_upper = $query->param("mask_upper");
	$mask_lower = $query->param("mask_lower");
	$quiet = 1;
}

#
# load the file
#

if ($no_cgi) {
	
	print STDERR "reading $text_id\n" unless ($quiet);
}

my $file = catfile($fs{data}, 'v3', Tesserae::metadata_get($text_id, "Lang"), $text_id, $text_id);

my @token = @{retrieve( "$file.token")};
my @line = @{retrieve( "$file.line")};

# validate mask

if (defined $part) {
	($mask_lower, $mask_upper) = Tesserae::get_mask($text_id, int($part));
}

if (defined $mask_lower) {
	$mask_lower = int($mask_lower);
	if ($mask_lower < 0) {
		$mask_lower = 0;
	} elsif ($mask_lower > $#token) {
		$mask_lower = $#token;
	}
} else {
	$mask_lower = 0;
}

if (defined $mask_upper) {
	$mask_upper = int($mask_upper);
	if ($mask_upper < 0) {
		$mask_upper = 0;
	} elsif ($mask_upper > $#token) {
		$mask_upper = $#token;
	}
} else {
	$mask_upper = $#token;
}

if ($mask_lower > $mask_upper) {
	($mask_lower, $mask_upper) = ($mask_upper, $mask_lower);
}

#
# display the full text
# 

my $unit_id = 0;

print "<table>";

for my $line_id (0..$#line) {
	my @token_ids = @{$line[$line_id]{TOKEN_ID}};

	next if ($token_ids[-1] < $mask_lower);
	last if ($token_ids[0] > $mask_upper);

	print "<tr>";
	print "<th>";
	print $line[$line_id]{LOCUS};
	print "</th>";
	print "<td>";

	my $span = "";	
	
	for my $token_id (@{$line[$line_id]{TOKEN_ID}}) {
		if ($token[$token_id]{TYPE} eq "WORD") {
			my $unit_id_ = $token[$token_id]{uc($unit) . "_ID"};

			if ($unit_id_ != $unit_id) {
				if ($span ne "") {
					print "<span class=\"u$unit_id\">$span</span>";
				}
				$unit_id = $unit_id_;
				$span = "";
			}
		}

		$span .= "<span class=\"t$token_id\">$token[$token_id]{DISPLAY}</span>";	
	}
	
	if ($span ne "") {
		print "<span class=\"u$unit_id\">$span</span>";
	}
	print "</td>";
	print "</tr>\n";
}



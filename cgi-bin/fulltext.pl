#!/usr/bin/env perl

#
#
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
binmode STDERR, ":utf8";

# print debugging messages to stderr?

my $quiet = 0;

# determine file from session id

my $session;

# help flag

my $help;

# is the program being run from the web or
# from the command line?

my $query = CGI->new() || die "$!";

my $no_cgi = defined($query->request_method()) ? 0 : 1;

if ($no_cgi) {
	# command-line input

	GetOptions(
		"session=s" => \$session,
		"quiet" => \$quiet
	);
} else {
	print header();

	# cgi input

	$session = $query->param('session');
	$quiet = 1;
}

# load results

my $file;

if (defined $session) {

	$file = catdir($fs{tmp}, "tesresults-" . $session);
}
else {

	die "no session specified";
}


#
# load the meta info for this search
#

print STDERR "reading $file\n" unless $quiet;
my %meta = %{retrieve(catfile($file, "match.meta"))};

#
# laod the template
#

my $html = load_template( catfile($fs{html}, "fulltext.html"));

$html =~ s/<!--session-->/$session/g;
$html =~ s/\/\*session\*\//"$meta{SESSION}"/;
$html =~ s/\/\*source\*\//"$meta{SOURCE}"/;
$html =~ s/\/\*target\*\//"$meta{TARGET}"/;
$html =~ s/\/\*part_source\*\//"$meta{PART_S}"/;
$html =~ s/\/\*part_target\*\//"$meta{PART_T}"/;
$html =~ s/\/\*unit\*\//"$meta{UNIT}"/;

# send to browser

print $html;

#
# subroutines
#

sub load_template {
	my $file = shift;

	my $html;

	open (my $fh, "<:utf8", $file) or die "Can't read $file: $!";

	while (my $line = <$fh>) {
		$html .= $line;
	}
	
	return $html;
}


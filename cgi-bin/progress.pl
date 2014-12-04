#!/usr/bin/env perl

=head1 NAME

progress.pl - return progress for a session

=head1 SYNOPSIS

progress.pl [options] --session SESSION

=head1 DESCRIPTION

Returns current job progress for a session.

=head1 OPTIONS AND ARGUMENTS

=over

=item B<--session> SESSION

Session to to check.

=item B<--help>

Print usage and exit.

=back

=head1 KNOWN BUGS

=head1 SEE ALSO

=head1 COPYRIGHT

University at Buffalo Public License Version 1.0.
The contents of this file are subject to the University at Buffalo Public License Version 1.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://tesserae.caset.buffalo.edu/license.txt.

Software distributed under the License is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for the specific language governing rights and limitations under the License.

The Original Code is progress.pl.

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

# initialize some variables

my $help = 0;
my $session;

# is the program being run from the web or
# from the command line?

my $query = CGI->new() || die "$!";

my $no_cgi = defined($query->request_method()) ? 0 : 1;

# get user options
if ($no_cgi) {

	GetOptions(
		'session=s' => \$session,
		'help'  => \$help
	);

	# print usage if the user needs help
	
	if ($help) {

		pod2usage(1);
	}
}
else {
	print header();
	$session = $query->param("session");
}

# fail if no session

unless (defined $session) {
	die "No session specified";
}

if ($session =~ /^[0-9a-f]{8}$/) {
	$session = "tesresults-" . $session;
}

unless (-d catfile($fs{tmp}, $session)) {
	die "Invalid session";
}

my $file = catfile($fs{tmp}, $session, ".progress");

open (my $fh, "<", $file) or die "Can't read $file: $!";

my @progress = <$fh>;

for (reverse @progress) {

	my $ref = decode_json($_);
	if (defined $ref->{msg} and defined $ref->{progress}) {
		print $_;
	}
}

print encode_json({msg => "", progress => "1%"});

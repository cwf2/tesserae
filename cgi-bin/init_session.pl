#!/usr/bin/env perl

=head1 NAME

init_session.pl - reserve a new session for a Tesserae search.

=head1 SYNOPSIS

B<init_session.pl> 

=head1 DESCRIPTION

Meant to be called from the web interface, this script creates a new directory in tmp, ready to hold search results.
It returns the session id, which can then be passed to read_table.pl with the B<--bin> flag.

=head1 OPTIONS 

=over

=item B<--help>

Print this message and exit.

=back

=head1 KNOWN BUGS

=head1 SEE ALSO

=head1 COPYRIGHT

University at Buffalo Public License Version 1.0.
The contents of this file are subject to the University at Buffalo Public License Version 1.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://tesserae.caset.buffalo.edu/license.txt.

Software distributed under the License is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for the specific language governing rights and limitations under the License.

The Original Code is init_session.pl

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
use File::Path qw(mkpath rmtree);
use JSON;

binmode STDERR, 'utf8';

#
# set some parameters
#

# help flag

my $help;

# is the program being run from the web or
# from the command line?

my $query = CGI->new() || die "$!";

my $no_cgi = defined($query->request_method()) ? 0 : 1;

if ($no_cgi) {
	# get command-line options

	GetOptions( 
		'help'         => \$help,
	);

	# print usage info if help flag set

	if ($help) {

		pod2usage(-verbose => 2);
	}
} else {
	print header("text/plain");
}

#
# determine the session ID
# 

# open the temp directory
# and get the list of existing session files

opendir(my $dh, $fs{tmp}) || die "can't opendir $fs{tmp}: $!";

my @tes_sessions = grep { /^tesresults-[0-9a-f]{8}/ && -d catfile($fs{tmp}, $_) } readdir($dh);

closedir $dh;

# sort them and get the id of the last one

@tes_sessions = sort(@tes_sessions);

my $session = $tes_sessions[-1];

# then add one to it;
# if we can't determine the last session id,
# then start at 0

if (defined($session)) {
	$session =~ s/^.+results-//;
} else {
	$session = "0"
}

# put the id into hex notation to save space and make it look confusing

$session = sprintf("%08x", hex($session)+1);

# open the new session file for output

my $file_results = catfile($fs{tmp}, "tesresults-$session");
mkpath($file_results);
	
if ($no_cgi) {
	print "$session\n";
} else {
	print encode_json({session => $session});
}


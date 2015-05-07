#!/usr/bin/env perl

=head1 NAME

convert-validation.pl

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 OPTIONS AND ARGUMENTS

=over

=item B<--help>

Print usage and exit.

=back

=head1 KNOWN BUGS

=head1 SEE ALSO

=head1 COPYRIGHT

University at Buffalo Public License Version 1.0.
The contents of this file are subject to the University at Buffalo Public License Version 1.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://tesserae.caset.buffalo.edu/license.txt.

Software distributed under the License is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for the specific language governing rights and limitations under the License.

The Original Code is convert-validation.pl.

The Initial Developer of the Original Code is Research Foundation of State University of New York, on behalf of University at Buffalo.

Portions created by the Initial Developer are Copyright (C) 2007 Research Foundation of State University of New York, on behalf of University at Buffalo. All Rights Reserved.

Contributor(s): Chris Forstall <cforstall@gmail.com>, James Gawley

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
use SynDiagnostic;
use EasyProgressBar;

# modules to read cmd-line options and print usage

use Getopt::Long;
use Pod::Usage;

# load additional modules necessary for this script

use DBI;
use Encode;

# initialize some variables

my $help;
my $quiet;

#
# get user options
#

GetOptions(
	"help"      => \$help,
   "quiet"     => \$quiet
);
	
# print usage if the user needs help

if ($help) {
	pod2usage(1);
}
   
binmode STDOUT, ":utf8";

my ($file_auth, $file_feat) = @ARGV[0,1];

my %index = %{read_auth_file($file_auth)};
read_feature_file($file_feat);

#
# subroutines
#

sub read_auth_file {
   my $file = shift;
   
   my %index;
   
   open (my $fh, "<:utf8", $file) or die "Can't read $file: $!";
   <$fh>;

   print STDERR "Reading validation data from $file\n" unless $quiet;
   
   while (my $line = <$fh>) {
      chomp $line;
      
      my @field = split(/\s+/, $line);
      
      next unless $#field == 27;

      my $query = $field[0];

      for (0..7) {
         my $result = $field[3+$_];
         my $valid = $field[12+$_];
         
         if ($result ne "NULL") {
            $index{$query}{$result} = $valid;
         }
      }
   }
   
   close $fh;
   return \%index;
}

sub read_feature_file {
  my $file = shift;

  open (my $fh, "<:utf8", $file) or die "Can't read $file: $!";
  
  print STDERR "Reading feature data from $file\n" unless $quiet;
  
  while (my $line = <$fh>) {
     chomp $line;
     my ($query, @result) = split(/,/, $line);
     
     next unless @result;
     
     for (@result) {
        
        my ($res, $prob) = split(/:/);
        next unless defined($index{$query}{$res});
        
        print join("\t", $query, $res, $prob, $index{$query}{$res}) . "\n";
     }
  }
  
  close $fh;
}
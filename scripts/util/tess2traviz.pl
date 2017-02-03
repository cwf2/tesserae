#!/usr/bin/env perl

=head1 NAME

tess2traviz.perl - prep tess results for traviz

=head1 SYNOPSIS

tess2traviz.pl [options] [--session] SESSION

=head1 DESCRIPTION

Reads results of a Tesserae search and produces data suitable for ingestion by
traviz visualisation software. SESSION should be either a local tesserae results
package (i.e. a directory) or else the id of an online session specified with
the B<-session> flag. Output will be two new files, each with the name of the
session:
  F<SESSION.txt>, the text file for traviz, and
  F<SESSION.score>, the score file for traviz.

=head1 OPTIONS AND ARGUMENTS

=over

=item I<SESSION>

By default, assumed to be a local directory containing the results of a Tesserae
search (F<match.meta>, F<match.source>, F<match.target>, F<match.score>). With
the B<-session> flag, SESSION is interpreted as the id of an online search and 
looked for in the appropriate directory.

=item B<--quiet>

Print less debugging info to STDERR.

=item B<--help>

Print usage and exit.

=back

=head1 KNOWN BUGS

=head1 SEE ALSO

=head1 COPYRIGHT

University at Buffalo Public License Version 1.0.
The contents of this file are subject to the University at Buffalo Public License Version 1.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://tesserae.caset.buffalo.edu/license.txt.

Software distributed under the License is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for the specific language governing rights and limitations under the License.

The Original Code is tess2traviz.pl.

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

use Storable;
use Data::Dumper;

# initialize some variables

my $session;
my $quiet = 0;
my $help = 0;

# get user options

GetOptions(
  'session' => \$session,
  'quiet' => \$quiet,
	'help'  => \$help
);

# print usage if the user needs help
	
if ($help) {
	pod2usage(1);
}

# get session from user input

my $file = shift @ARGV;

if ($session) {
  $file = catfile($fs{tmp}, $session);
} else {
  $session = $file;
}

unless (defined($file) and -d $file) {
  print "Can't find session data!";
  pod2usage(2);
}

# read the session data 
print STDERR "Loading session data\n" unless $quiet;
my %meta = %{retrieve(catfile($file, "match.meta"))};
my %match_target = %{retrieve(catfile($file, "match.target"))};
my %match_source = %{retrieve(catfile($file, "match.source"))};
my %score = %{retrieve(catfile($file, "match.score"))};

# load the original texts 
print STDERR "Loading texts\n" unless $quiet;
my $target = $meta{TARGET};
my $source = $meta{SOURCE};
my $unit = $meta{UNIT};

my $base_target = catfile(
    $fs{data}, "v3", Tesserae::lang($target), $target, $target);
my @token_target = @{retrieve("$base_target.token")};
my @unit_target = @{retrieve("$base_target.$unit")};

my $base_source = catfile(
    $fs{data}, "v3", Tesserae::lang($source), $source, $source);
my @token_source = @{retrieve("$base_source.token")};
my @unit_source = @{retrieve("$base_source.$unit")};

# convert text names to id numbers
print STDERR "Building corpus directory\n" unless $quiet;
my %by_name = %{gen_text_id()};

# write text file
write_txt();

# process scores
my @rec = @{process_scores()};

# write score file
write_score();

#
# subroutines
#

sub gen_text_id {
  # make id numbers for all the texts
  my @textlist = @{Tesserae::metadata_textlist()};
  
  my %by_name;
  my $ndigits = length(scalar(@textlist));
  
  for my $i (0 .. $#textlist) {
    $by_name{$textlist[$i]} = sprintf("%0${ndigits}i", $i);
  }
  
  return \%by_name;
}


sub write_txt {
  # write the text file

  my $file_text = "$session.txt";
  if (-e $file_text) {
    print STDERR "$file_text already exists: clobbering!\n" unless $quiet;
  }

  print STDERR "Writing $file_text\n" unless $quiet;
    
  open (my $fh, ">:utf8", $file_text) or die "Can't write $file_text: $!";
  for my $unit_id_target (0..$#unit_target) {
    my $id = $by_name{$target} . sprintf("%06i", $unit_id_target);
    my $tag = join(" ", "$target.txt", $unit_target[$unit_id_target]{LOCUS});
    my $text = join("", map {$token_target[$_]{DISPLAY}} 
      @{$unit_target[$unit_id_target]{TOKEN_ID}});
    
    print $fh join("\t", $id, $text, "NULL", $tag) . "\n";
  }
  for my $unit_id_source (0..$#unit_source) {
    my $id = $by_name{$source} . sprintf("%06i", $unit_id_source);
    my $tag = join(" ", "$source.txt", $unit_source[$unit_id_source]{LOCUS});
    my $text = join("", map {$token_source[$_]{DISPLAY}} 
      @{$unit_source[$unit_id_source]{TOKEN_ID}});
    
    print $fh join("\t", $id, $text, "NULL", $tag) . "\n";
  }

  close $fh;
}

sub process_scores {
  # convert score to traviz format
  print STDERR "Processing scores\n" unless $quiet;
  
  my @rec;
  
  for my $unit_id_target (keys %score) {
    for my $unit_id_source (keys %{$score{$unit_id_target}}) {
      # id tags for texts
      my $id_target = $by_name{$target} . sprintf("%06i", $unit_id_target);
      my $id_source = $by_name{$source} . sprintf("%06i", $unit_id_source);

      # count the number of features
      my %feature_count_target;
      
      for my $token_id_target (keys %{$match_target{$unit_id_target}{$unit_id_source}}) {
        for my $f (keys %{$match_target{$unit_id_target}{$unit_id_source}{$token_id_target}}) {
          $feature_count_target{$f} ++; 
        }
      }

      my %feature_count_source;
      for my $token_id_source (keys %{$match_source{$unit_id_target}{$unit_id_source}}) {
        for my $f (keys %{$match_source{$unit_id_target}{$unit_id_source}{$token_id_source}}) {
          $feature_count_source{$f} ++; 
        }
      }
      
      my $features = 0;
      for my $f (keys %feature_count_target) {
        if ($feature_count_target{$f} < $feature_count_source{$f}) {
          $features += $feature_count_target{$f};
        } else {
          $features += $feature_count_source{$f};
        }
      }
            
      # score
      my $score = $score{$unit_id_target}{$unit_id_source};
      
      push @rec, {
        target => $id_target,
        source => $id_source,
        features => $features,
        score => $score
      };
    }
  }
  
  print STDERR "Scaling\n" unless $quiet;
  
  my $max = 0;
  
  for my $r (@rec) {
    if ($r->{score} > $max) { $max = $r->{score} }
  }
  for my $r (@rec) {
    $r->{score} /= $max;
  }
  
  return \@rec;
}


sub write_score {
  # write the score file
    
  my $file_score = "$session.score";
  if (-e $file_score) {
    print STDERR "$file_score already exists: clobbering!\n" unless $quiet;
  }

  print STDERR "Writing $file_score\n" unless $quiet;
    
  open (my $fh, ">:utf8", $file_score) or die "Can't write $file_score: $!";
  
  for my $r (@rec) {
    print $fh join("\t", 
      $r->{source},
      $r->{target},
      sprintf("%.1f", $r->{features}),
      sprintf("%.1f", $r->{score})
    );
    print $fh "\n";
  }
  
  close $fh;
}

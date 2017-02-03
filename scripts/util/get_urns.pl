#!/usr/bin/env perl

=head1 NAME

get_urns.pl - link tess files Perseus URNs

=head1 SYNOPSIS

get_urns.pl [options]

=head1 DESCRIPTION

Compare filenames in the texts database with metadata from the "metadata_db" branch;
cross-check against the index provided by Perseus' CTS API.

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

The Original Code is get_urns.pl.

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

use XML::LibXML;
use Storable;
use DBI;

# initialize some variables

my $server = "http://www.perseus.tufts.edu/hopper/CTS";
my $dbname = "/home/vagrant/urns.db";
my $tessmeta = "/home/vagrant/texts.xml";
my $clean = 0;
my $quiet = 0;
my $help = 0;

my @texts = qw/
   vergil.aeneid
   ovid.amores
   ovid.remedia_amoris
   ovid.ars_amatoria
   ovid.heroides
   ovid.metamorphoses   
   statius.achilleid
/; 

# xpath namespaces used by CTS

my $xpc = init_xpath_context({
   cts => "http://chs.harvard.edu/xmlns/cts3",
   ti => "http://chs.harvard.edu/xmlns/cts3/ti",
   tei => "http://www.tei-c.org/ns/1.0"
});

# get user options

GetOptions(
   "server=s" => \$server,
   "dbname=s" => \$dbname,
   "tessmeta=s" => \$tessmeta,
   "clean!" => \$clean,
   "quiet" => \$quiet,
	"help" => \$help
);

# print usage if the user needs help
	
if ($help) {

	pod2usage(1);
}

# create/connect to db

my $dbh = db_init($dbname, $clean);

# read Tesserae metadata

my %urn = %{read_tess_meta($tessmeta)};

for my $text (@texts) {
   verify($text, $urn{$text});
}


#
# subroutines
#

sub db_init {
   my ($dbname, $clean) = @_;
 
   # destroy existing database if clean flag set
   
   if ($clean) {
      if (-f $dbname) {
         unlink $dbname;
      }
   }
   
   # create db connection
   
	my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", "", "", {RaiseError=>1});
   
   # create table if necessary
   
	db_create_table($dbh, "texts", [
      "id varchar(128)",
      "urn varchar(80)"]
	);   
   
   # return db handle
   
	return $dbh;
}

sub db_create_table {
	my ($dbh, $table, $cols_ref) = @_;
	my @cols = @$cols_ref;

	$dbh->do("create table if not exists $table (" . join(",", @cols) . ");");
}

sub read_tess_meta {
   my $file = shift;
   
   my %urn;
   
   print STDERR "Reading $file\n" unless $quiet;
   
   my $doc = XML::LibXML->load_xml(location=>$file);
   
   for my $textnode ($doc->findnodes("//TessDocument")) {
      my $id = $textnode->getAttribute("id");
      my $urn = $textnode->findvalue("URI");
      
      next unless $urn;
      $urn{$id} = $urn;
   }
   
   return \%urn;
}

sub cts_request {
   my ($server, $request, $ref_opt) = @_;
   my %opt = %$ref_opt;
   
   # serialize options
   my $opt_str = join("", map {"\&$_=$opt{$_}"} keys %opt);
   
   # create url
   my $url = $server . "?request=" . $request . $opt_str;
   
   # send query, parse response
   my $res;

   print STDERR "cts_request: $url\n" unless $quiet;

   # check for errors
   eval {
      $res = XML::LibXML->load_xml(location=>$url);
   };
   if ($@) {
      # can't parse response
      print STDERR "CTS request failed: $@\n";
   } else {
      # parsable CTS error message
      
      my $err = $xpc->findnodes("/cts:CTSError", $res)->get_node(1);
      
      if ($err) {
         my $msg = $xpc->findvalue("cts:message", $err);
         
         print STDERR "CTS request failed: $msg\n";
         $res = undef;
      }
   }
   
   return $res;
}

sub cts_get_valid_reff {
   my $urn = shift;

   my @suffix;
   
   my $res = cts_request($server, "GetValidReff", {urn=>$urn});

   if (defined $res) {
      my $reff = $xpc->findnodes("//ti:reff", $res)->get_node(1);
   
      if (defined $reff) {
         for my $urn_node ($xpc->findnodes("ti:urn", $reff)) {
            my $urn_ = $urn_node->textContent();
            next unless $urn_ =~ /^${urn}:(.+)/;
            push @suffix, $1;
         }
      }
   }
      
   print STDERR " - $urn => [" . scalar(@suffix) . "] units\n" unless $quiet;
   
   return \@suffix;
}

sub cts_get_passage {
   my $urn = shift;
   
   my $textcontent;
   
   my $res = cts_request($server, "GetPassage", {urn=>$urn});
   
   if (defined $res) {
      my $teitext_node = $xpc->findnodes("//tei:text", $res)->get_node(1);
   
      $textcontent = $xpc->findvalue("tei:body", $teitext_node);
   }
   
   return $textcontent;
}

sub init_xpath_context {
   my $ref_ns = shift;
   my %ns = %$ref_ns;
   
   my $xpc = XML::LibXML::XPathContext->new();
   
   for my $k (keys %ns) {
      $xpc->registerNs($k, $ns{$k});
   }
   
   return $xpc;
}

sub verify {
   my ($text_id, $urn) = @_;
   
   print STDERR "Verifying $text_id:\n";
   
   my $base = catfile($fs{data}, "v3", "la", $text_id, $text_id);
   my @tess_line = @{retrieve("$base.line")};
      
   my @cts_suff = @{cts_get_valid_reff($urn)};

   my %index_tess;
   for my $i (0..$#tess_line) {
      my $loc = $tess_line[$i]{LOCUS};
      
      if (exists $index_tess{$loc}) {
         print STDERR " Tesserae has duplicate loc $loc: $index_tess{$loc},$i";
      }
      $index_tess{$loc} = $i;
   }
   
   my %index_cts;
   for my $i (0..$#cts_suff) {
      $index_cts{$cts_suff[$i]} = $i;
   }
   
   my %idmap;
   for (keys %index_tess) {
      $idmap{$_}{tess} = $index_tess{$_};
   }
   for (keys %index_cts) {
      $idmap{$_}{cts} = $index_cts{$_};
   }
   
   my %tally = (both => [], tess => [], cts => []);
   for (keys %idmap) {
      my $stat = "both";
      unless (defined $idmap{$_}{tess}) { 
         $stat = "cts";
      }
      unless (defined $idmap{$_}{cts}) {
         $stat = "tess";
      }
      
      push @{$tally{$stat}}, $_;
   }
   
   for (qw/both tess cts/) {
      print STDERR "  " . join("\t", $_, scalar(@{$tally{$_}})) . "\n";
   }
   
   if (scalar(@{$tally{cts}}) + scalar(@{$tally{both}}) > 0) {
      if (@{$tally{tess}}) {
         print STDERR " Tess only:";
         for (sort {$index_tess{$a} <=> $index_tess{$b}} @{$tally{tess}}) {
            print STDERR " $_";
         }
         print STDERR "\n";
      }
      if (@{$tally{cts}}) {
         print STDERR " CTS only:";
         for (sort {$index_cts{$a} <=> $index_cts{$b}} @{$tally{cts}}) {
            print STDERR " $_";
         }
         print STDERR "\n";
      }
   }
   
   my @tess_to_cts;
   $#tess_to_cts = $#tess_line;
   
   for (@{$tally{"both"}}) {
      $tess_to_cts[$index_tess{$_}] = $cts_suff[$index_cts{$_}];
   }
   
   return \@tess_to_cts;
}
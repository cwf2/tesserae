#! /usr/bin/perl

=head1 NAME

import_xml.pl - add texts to the tesserae database

=head1 SYNOPSIS

import_xml.pl [options] TEXT [, TEXT2, [DIR], ...] 

=head1 DESCRIPTION

Reads in one or more .xml documents and creates the indices used by read_table.pl
to perform Tesserae searches.

This script is usually run on an entire directory of texts at once, when you're
first setting Tesserae up.  E.g. (from the Tesserae root dir),

   scripts/v3/import_xml.pl texts/xml/*

Adapted from add_column.pl; the actual parsing of units and tokens should'be
unchanged.

=head1 OPTIONS AND ARGUMENTS

=over

=item B<--override FIELD=VALUE>

Manually set any of the metadata fields that should otherwise be read from 
the source document.

=item B<--parallel N>

Allow up to N processes to run in parallel.  Requires Parallel::ForkManager.

=item B<--use-lingua-stem>

Use the Lingua::Stem module to do stemming instead of internal dictionaries.
This is the only way to index English works by stem; I don't think it works
for Latin and almost certainly not for Greek.  The language code will be 
passed to Lingua::Stem, which must have a stemmer for that code.

=item B<--help>

Print usage and exit.

=back

=head1 KNOWN BUGS

=head1 SEE ALSO

=head1 COPYRIGHT

University at Buffalo Public License Version 1.0.
The contents of this file are subject to the University at Buffalo Public License Version 1.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://tesserae.caset.buffalo.edu/license.txt.

Software distributed under the License is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for the specific language governing rights and limitations under the License.

The Original Code is import_xml.pl.

The Initial Developer of the Original Code is Research Foundation of State University of New York, on behalf of University at Buffalo.

Portions created by the Initial Developer are Copyright (C) 2007 Research Foundation of State University of New York, on behalf of University at Buffalo. All Rights Reserved.

Contributor(s): Chris Forstall <forstall@buffalo.edu>, James Gawley, Neil Coffee

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

use utf8;
use File::Path qw(mkpath rmtree);
use File::Basename;
use File::Copy;
use Storable qw(nstore retrieve);
use XML::LibXML;
use Encode;

# optional modules

my $override_stemmer  = Tesserae::check_mod("Lingua::Stem");
my $override_parallel = Tesserae::check_mod("Parallel::ForkManager");

#
# splitting phrases
#

# a complicated regex to test for their presence
# if you match this $1 and $2 will be set to the parts
# belonging to the left and right phrases respectively

my $split_punct = qr/(.*$phrase_delimiter['"’”]?)(\s*)(.*)/;

# 
# initialize some parameters
# 

# these are for optional use of Lingua::Stem

my $use_lingua_stem = 0;
my $stemmer;

#
# for parallel processing
#

my $max_processes = 0;
my $pm;

# manually-specified fields and values
my @override_list;

# don't print messages to STDERR 
my $quiet = 0;

# print usage and exit
my $help = 0;

# allow utf8 output to stderr
binmode STDERR, ':utf8';

#
# command line options
#

GetOptions( 
	"override=s"      => \@override_list,
	"parallel=i"      => \$max_processes,
	"quiet"           => \$quiet,
	"use-lingua-stem" => \$use_lingua_stem,
	"help"            => \$help
	);

# print usage if the user needs help
	
if ($help) {

	pod2usage(1);
}

# check to make sure stemmer module is available

if ($use_lingua_stem and $override_stemmer) {

	print STDERR 
		"Lingua::Stem was not installed when you configured Tesserae.  "
	   . "If you have installed it since then, please re-configure.  "
	   . "Falling back on stem dictionary method for now.\n";
	   
	$use_lingua_stem = 0;
}

#
# initialize parallel processing
#

if ($max_processes and $override_parallel) {

	print STDERR "Parallel processing requires Parallel::ForkManager from CPAN.\n";
	print STDERR "Proceeding with parallel=0.\n";
	$max_processes = 0;

}

if ($max_processes) {

	$pm = Parallel::ForkManager->new($max_processes);
}

# check override settings
my %override;
for (@override_list) {
	next unless /(\S+)=(\S+)/;
	$override{$1} = $2;
}

# get files to be processed from cmd line args

my @files = @ARGV;

unless (@files) {

	print STDERR "No files specified\n";
	pod2usage(2);
}


#
# process the files
#

for my $file (@files) {
				
	#
	# fork
	#
	
	if ($max_processes) {

		$pm->start and next;
	}
	
	# parse xml
	
	my $dom = eval {XML::LibXML->load_xml(location=>$file)};
	
	unless ($dom) {
		print STDERR "Can't parse $file";
		print STDERR ": $@" if $@;
		print STDERR "\n";
		
		$pm->finish if $max_processes;
		next;
	}
	
	# get text id
	
	my $text_id = $dom->documentElement->getAttribute("id");
	unless (defined $text_id and $text_id ne "") {
		print STDERR "skipping $file: <id> field is missing\n";
		$pm->finish if $max_processes;
		next;
	}
	
	# look for header
	
	my %text_metadata;
	my $head = $dom->findnodes("TessDocument/Metadata");
	if (defined $head and $head->size == 1) {
		$head=$head->get_node(1);
		
		for my $field (@Tesserae::metadata_fields_texts) {			
			if ($override{$field}){
				$text_metadata{$field} = $override{$field};
			} else {
				$text_metadata{$field} = $head->findvalue($field);
			}
			
			unless ($text_metadata{$field}) {
				print STDERR "$file lacks metadata field <$field>\n";
			}
		}
	}
	
	# validate required fields
	
	for my $field (qw/Author Display Lang Prose/) {
		unless (defined $text_metadata{$field}) {
			print STDERR "Skipping $file: required metadata is missing\n";
			$pm->finish if $max_processes;
			next;
		}
	}
	
	# make sure there is some text
	
	my $body = $dom->findnodes("TessDocument/Text/TextUnit");
	unless (defined $body and $body->size > 0) {
		print STDERR "Skipping $file: no text found\n";
		$pm->finish if $max_processes;
		next;
	}
	
	# add the text into metadata table
		
	my $dbh = Tesserae::metadata_dbh;

	$dbh->do("insert or replace into texts (" 
		. join(",", "id", @Tesserae::metadata_fields_texts)
		. ") values (" 
		. join(",", map {defined $_ ? "\"$_\"" : "NULL"} 
			($text_id, @text_metadata{@Tesserae::metadata_fields_texts}))
		. ")");

	# register with parts table 
	# TODO
	
	# check authors table 
	# TODO
	
	#
	# initialize variables
	#
	
	my @token;
	my @line;
	my @phrase = ({});

	my %index_word;

	my $lang = $text_metadata{Lang};

	# assume unknown lang is like english
	
	unless (defined $is_word{$lang})  { $is_word{$lang}  = $is_word{en} }
	unless (defined $non_word{$lang}) { $non_word{$lang} = $non_word{en} }

	# parse and index:
	# - every word will get a serial id
	# - every line is a list of words
	# - every phrase is a list of words

	print STDERR "Reading text: $text_id\n" unless $quiet;

	# assume first quote mark is a left one
	
	my $toggle = 1;

	# examine each line of the input text

	for my $text_unit ($body->get_nodelist) {
		my $verse = $text_unit->textContent;
		my $locus = $text_unit->getAttribute("loc");
		my $unit_id = $text_unit->getAttribute("id");
		
		for ($verse, $locus, $unit_id) { 
			next unless defined $_;
		}

		# start a new line
		
		push @line, {};
		
		# save the book/poem/line number

		$line[-1]{LOCUS} = $locus;

		# remove html special chars

		$verse =~ s/&[a-z];//ig;
		$verse =~ s/[<>]//g;

		#
		# check for enjambement with prev line
		#
		
		if (defined $phrase[-1]{TOKEN_ID}) {

			push @token, {TYPE => 'PUNCT', DISPLAY => ' / '};
			push @{$phrase[-1]{TOKEN_ID}}, $#token;
		}
		
		# split the line into tokens				
		# add tokens to the current phrase, line

		while (length($verse) > 0) {
			
			#
			# add word token
			#
			
			if ( $verse =~ s/^($is_word{$lang})// ) {
			
				my $token = $1;
			
				# this display form
				# -- just as it appears in the text

				my $display = $token;
				
				#
				# an experimental feature
				#
				
				if ($token =~ /TESSFORM(.+?)TESSDISPLAY(.+?)/) {
				
					($token, $display) = ($1, $2);
				}

				# the searchable form 
				# -- flatten orthographic variation

				my $form = Tesserae::standardize($lang, $token);

				# add the token to the master list

				push @token, { 
					TYPE => 'WORD',
					DISPLAY => $display, 
					FORM => $form ,
					LINE_ID => $#line,
					PHRASE_ID => $#phrase
				};

				# add token id to the line and phrase

				push @{$line[-1]{TOKEN_ID}}, $#token;
				push @{$phrase[-1]{TOKEN_ID}}, $#token;

				# note that this phrase extends over this line

				$phrase[-1]{LINE_ID}{$#line} = 1;
				
				#
				# index
				#
				
				push @{$index_word{$form}}, $#token;				
			}

			#
			# add punct token
			#
			
			elsif ( $verse =~ s/^($non_word{$lang})// ) {
			
				my $token = $1;
				
				# tidy up double quotation marks
				
				while ($token =~ /"/) {

					my $quote = $toggle ? '“' : '”';

					$token =~ s/"/$quote/;

					$toggle = ! $toggle;
				}
			
				# check for phrase-delimiting punctuation
				#
				# if we find any, then this token should
				# be split into two, so that one part can
				# go with each phrase.

				if ($token =~ $split_punct) {

					my ($left, $space, $right) = ($1, $2, $3);

					push @token, {TYPE => 'PUNCT', DISPLAY => $left};

					push @{$line[-1]{TOKEN_ID}}, $#token;
					push @{$phrase[-1]{TOKEN_ID}}, $#token;

					# add intervening white space to the line,
					# but not to either phrase

					if ($space ne '') {

						push @token, {TYPE => 'PUNCT', DISPLAY => $space};
						push @{$line[-1]{TOKEN_ID}}, $#token;
					}

					# start a new phrase

					push @phrase, {};
					
					# now let the body of the function handle what remains

					$token = $right;
				}

				# skip empty strings

				if ($token ne '') {

					# add to the current phrase, line

					push @token, {TYPE => 'PUNCT', DISPLAY => $token};

					push @{$line[-1]{TOKEN_ID}}, $#token;
					push @{$phrase[-1]{TOKEN_ID}}, $#token;
				}
			}
			else {
				
				print STDERR "Can't parse TextUnit $unit_id...skipping.";
				next;
			}
		}
	}
	
	# if the poem ends with a phrase-delimiting punct token,
	# there will be an empty final phrase;
	# if the poem ends with the sequence ." you can end up
	# with a final phrase composed of " alone.  Check for
	# these and delete
	
	my $haswords = 0;
	
	for (@{$phrase[-1]{TOKEN_ID}}) {
	
		if ($token[$_]{TYPE} eq 'WORD') {
		
			$haswords = 1;
			last;
		}
	}
	
	unless ($haswords) {
	
		push @{$phrase[-2]{TOKEN_ID}}, @{$phrase[-1]{TOKEN_ID}};
	
		pop @phrase;
	}
	
	#
	# tidy up relationship between phrases and lines:
	#  - convert the LINE_ID tag of phrases to a simple array
	#
		
	for my $phrase_id (0..$#phrase) { 
		
		$phrase[$phrase_id]{LINE_ID} = [sort {$a <=> $b} keys %{$phrase[$phrase_id]{LINE_ID}} ];

		# if there's a range, just use the first line
			
		$phrase[$phrase_id]{LOCUS} = $line[$phrase[$phrase_id]{LINE_ID}[0]]{LOCUS};
	}
		
	#
	# save the data
	#
	
	# make sure the directory exists
	
	my $path_data = catfile($fs{data}, 'v3', $lang, $text_id);
	
	unless (-d $path_data ) { mkpath($path_data) }
	
	my $file_out = catfile($path_data, $text_id);

	print STDERR "Writing $file_out.token\n" unless $quiet;
	nstore \@token, "$file_out.token";

	print STDERR "Writing $file_out.line\n" unless $quiet;
	nstore \@line, "$file_out.line";
	
	print STDERR "Writing $file_out.phrase\n" unless $quiet;
	nstore \@phrase, "$file_out.phrase";

	print STDERR "Writing $file_out.index_word\n" unless $quiet;
	nstore \%index_word, "$file_out.index_word";
		
	# calculate frequencies for stoplist

	Tesserae::write_freq_stop($text_id, 'word', \%index_word, $quiet);
	
	# frequencies for score are the same
	
	my $from = "$file_out.freq_stop_word";
	my $to   = "$file_out.freq_score_word";
	
	print STDERR "Writing $to\n" unless $quiet;
	copy($from, $to);
	
	# mark text as indexed by word
	Tesserae::metadata_set($text_id, "feat_word", 1, $dbh);

	$pm->finish if $max_processes;
}

$pm->wait_all_children if $max_processes;

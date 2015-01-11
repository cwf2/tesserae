#!/usr/bin/env perl

=head1 NAME

doc_gen.pl - Generate the HTML formatted documentation for Tesserae.

=head1 SYNOPSIS

doc_gen.pl [options]

=head1 DESCRIPTION

This script should be run after configure.pl. It seeks out the script folder
and all expected subdirectories looking for scripts with POD documentation in
their headers. Then it creates a folder inside tesserae/doc/ where it stores
HTML versions of these descriptions.

=head1 OPTIONS AND ARGUMENTS

=over

=item B<--help>

Print usage and exit.

=back

=head1 KNOWN BUGS

=head1 SEE ALSO

=head1 COPYRIGHT

University at Buffalo Public License Version 1.0. The contents of this file
are subject to the University at Buffalo Public License Version 1.0 (the
"License"); you may not use this file except in compliance with the License.
You may obtain a copy of the License at
http://tesserae.caset.buffalo.edu/license.txt.

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is doc_gen.pl.

The Initial Developer of the Original Code is Research Foundation of State
University of New York, on behalf of University at Buffalo.

Portions created by the Initial Developer are Copyright (C) 2007 Research
Foundation of State University of New York, on behalf of University at
Buffalo. All Rights Reserved.

Contributor(s): James Gawley

Alternatively, the contents of this file may be used under the terms of
either the GNU General Public License Version 2 (the "GPL"), or the GNU
Lesser General Public License Version 2.1 (the "LGPL"), in which case the
provisions of the GPL or the LGPL are applicable instead of those above. If
you wish to allow use of your version of this file only under the terms of
either the GPL or the LGPL, and not to allow others to use your version of
this file under the terms of the UBPL, indicate your decision by deleting the
provisions above and replace them with the notice and other provisions
required by the GPL or the LGPL. If you do not delete the provisions above, a
recipient may use your version of this file under the terms of any one of the
UBPL, the GPL or the LGPL.

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
use Pod::Simple::HTML;

# initialize some variables

my $help = 0;
my $quiet = 0;

# get user options

GetOptions(
	'help'  => \$help,
   'quiet' => \$quiet
);

#
# print usage if the user needs help
#
# you could also use perldoc name.pl
	
if ($help) {

	pod2usage(1);
}

#Initialize filepath variables for the documents and scripts folders.
my @perl_scripts = match_files(qr/\.pl$/, $fs{script}, $fs{cgi});
my @pod_standalone = match_files(qr/\.pod$/, catfile($fs{doc}, "pod"));

# Initialize a hash which will translate file paths to unique integer ids
# used to store help info
my %id;

# build html documentation

for my $file_in (@perl_scripts, @pod_standalone) {

   my $html = generate_html($file_in);
   unless ($html) {
      warn "$file_in generated no html documentation";
      next;
   }

   $id{$file_in} = scalar(keys %id);

   my $file_out = catfile($fs{doc}, "html", $id{$file_in} . ".html");

   my $fh;
   unless (open ($fh, ">:utf8", $file_out)) {
      warn "Can't write $file_out: $!";
      next;
   }
   
   print STDERR "writing $file_out\n";
   
   print $fh $html;
   close ($fh);
}

# create html index
{
   my $html = html_index_template();
   
   my $scripts_index = toc2html(build_toc(\@perl_scripts, 
      {base=>$fs{root}}));
   my $general_index = toc2html(build_toc(\@pod_standalone, 
      {flat=>1}), {pretty=>1});
   
   $html =~ s/<!--general-->/$general_index/;
   $html =~ s/<!--scripts-->/$scripts_index/;
   
   my $file_out = catfile($fs{doc}, "html", "index.html");

   open (my $fh, ">:utf8", $file_out) or die "Can't write $file_out: $!";
   print $fh $html;
   close $fh;
}



#
# subroutines
#

sub match_files {
   # recursively search specified directories for files
   # matching a regular expression

   my ($re, @dir) = @_;
   
   my @match;
   
   for my $dir (@dir) {
      print STDERR "checking $dir\n" unless $quiet;
      
      opendir(my $dh, $dir) or die "Can't read $dir: $!";
      
      my @files = grep {$_ !~ /^\./} readdir($dh);
      @files = map {catfile($dir, $_)} @files;
      
      for my $file (@files) {
         if (-d $file) {
            push @match, match_files($re, $file);
         }
         else {
            if ($file =~ $re) {
               push @match, $file;
            }
         }
      }
      
      closedir($dh);
   }
   
   return @match;
}


sub build_toc {
   # build a table of contents organized by path

   my ($file_ref, $opt_ref) = @_; 
   my @files = @$file_ref;
   my %opt;
   if (defined $opt_ref) {
      %opt = %$opt_ref;
   }

   my %toc;

   for my $full_path (@files) {
      # ignore files that didn't generate html documentation
      
      next unless defined $id{$full_path};
      
      # add file path to table of contents
      
      my ($vol, $dir, $file) = File::Spec->splitpath($full_path);
   
      if ($opt{flat}) {
         # in flat mode, just index the file under its name,
         # ignoring path and .pod extension, if any
         $toc{$file} = $full_path;
         
      } else {
         # otherwise, store nested directories in order
   
         if ($opt{base}) {
            $dir =~ s/^$opt{base}//;
         }
                  
         my @dir = File::Spec->splitdir($dir);
                  
         if ($dir[0] eq "") { 
            shift @dir;
         }
         if ($dir[-1] eq "") {
            pop @dir;
         }
         
         my $ref = \%toc;

         for my $key (@dir) {
            unless (exists $ref->{$key}) {
               $ref->{$key} = {};
            }
            $ref = $ref->{$key};
         }

         $ref->{$file} = $full_path;
      }
   }
   
   return \%toc;
}



sub toc2html {
   # recursive function to turn table of contents into a 
   # nested <ul> list of links

   my ($toc_ref, $opt_ref) = @_;
   
   my %toc = %$toc_ref;
   my %opt;
   if (defined $opt_ref) {
      %opt=%$opt_ref;
   }
      
   my $ul = "<ul>";
   
   for my $key (sort keys %toc) {

      my $display = $key;
      if ($opt{pretty}) {
         $display =~ s/\.pod^//;
         $display =~ s/^\d+\.//;
         $display =~ s/_/ /g;
      }
      
      my $li;
      
      if (ref($toc{$key}) eq "HASH") {
         # if the entry corresponds to a nested subdirectory, 
         # call this function again recursively
         
         $li .= "<li>$display/</li>";
         $li .= "<li>";
         $li .= toc2html($toc{$key});
         $li .= "</li>";
         
      } else {
         # if the entry corresponds to a help file, add it
         
         my $id = $id{$toc{$key}};
         
         $li .= "<li>";
         $li .= "<a id=\"doc_$id\" href=\"$url{doc}/$id.html\">";
         $li .= $display;
         $li .= "</a>";
         $li .= "</li>";         
      } 
      
      $ul .= $li;
   }
   
   $ul .= "</ul>";
  
   return $ul;
}


sub generate_html {
   # use Pod::Simple::HTML to generate web page from pod
   
   my $file = shift;
   
   $Pod::Simple::HTML::Content_decl = q{<meta charset="UTF-8" >};
   my $p = Pod::Simple::HTML->new;
   
   $p->html_css('/css/doc.css');
   
   my $html;
   $p->output_string(\$html);
   
   $p->parse_file($file);
   
   return $html;
}


sub transform_html {
   # parse default generated html and extract just the body,
   # repackaged as a <div> element
   
   my $html = shift;
   
   my $dom = XML::LibXML->load_html(string=>$html);
   
   my $div = $dom->createElement("div");
   # $div->setAttribute("class", "pod");
     
   my $body = $dom->findnodes("//body")->get_node(1);
   for my $child ($body->childNodes()) {
      # skip comments
      next if $child->nodeType == 8;
      
      # otherwise, clone children
      $div->appendChild($child->cloneNode(1));
   }
 
   return $div->toString();
}


sub html_index_template {
   # generate html index file
   
   my $html = <<END_HTML;
<!DOCTYPE html>
<html>
   <head>
      <meta charset="UTF-8">
      <title>Tesserae Documentation</title>
      <link rel="stylesheet" href="$url{css}/doc.css" type="text/css" />
      <style type="text/css">
         div.scripts ul {
            list-style-type: none;
         }
      </style>
   </head>
   <body>
   <div class="general">
      <h1>Help Topics</h1>
      <!--general-->
   </div>
   <div class="scripts">
      <h1>Code Documentation</h1>
      <!--scripts-->
   </div>
   </body>
</html>

END_HTML

   return $html;
}
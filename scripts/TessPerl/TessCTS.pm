package TessCTS;

use XML::LibXML;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = ();
our @EXPORT_OK = ();
our $VERSION = '3.1.0_0';

# assign some default values

# CTS server location
my $server = "http://www.perseus.tufts.edu/hopper/CTS";

# useful xpath namespace shorthands
my $xpc = init_xpath_context({
   cts => "http://chs.harvard.edu/xmlns/cts3",
   ti => "http://chs.harvard.edu/xmlns/cts3/ti",
   tei => "http://www.tei-c.org/ns/1.0"
});

# for debugging
my $quiet = 0;


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


# return 1
1;
package SynDiagnostic;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw();
our @EXPORT_OK = qw();
our $VERSION = '3.1.0_0';

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

# other modules

use DBI;
use Data::Dumper;

#
# guess whether a word is greek
#

sub lang {

	my $token = shift;
	
   $token =~ s/[^[:alpha:]]//g;
   
	my @c = split(//, $token);
	
	for (@c) {
		
		if (ord($_) > 255) {

			return "grc";
		}
	}
	
	return "la";
}

sub db_connect {
   # connect to featureset database
   
   my ($file_db, %opt) = @_;
      
   # print STDERR "Connecting to $file_db\n" unless $opt{quiet};
   #
   # if ($opt{clean}) {
   #    if (-e $file_db) {
   #       print STDERR "Clobbering existing db\n" unless $opt{quiet};
   #       unlink $file_db if -e $file_db;
   #    }
   #    $opt{create} = 1;
   # }
   #
   # unless (-s $file_db or $opt{create}) {
   #    warn "Feature database $feat not installed.";
   #    return undef;
   # }
   
   my $dbh = DBI->connect("dbi:SQLite:dbname=$file_db", "", "", 
      {RaiseError => 1, sqlite_unicode => 1});
   	   
   return $dbh;
}

sub check_table {
   # check for table's existence
   my ($dbh, $name) = @_;
   
	my $exists = $dbh->selectrow_arrayref(
		qq{select name from sqlite_master where type="table" and name="$name"}
	);
   
   return ($exists ? 1 : 0);
}

sub create_table {
   # create table
   my ($dbh, $name, $ref_col) = @_;
   my @col = @$ref_col;
   
   my $definition = join(",", map {join(" ", $_->[0], $_->[1])} @col);
   
   $dbh->do(
		qq{create table $name ($definition)}
	);
}

1;
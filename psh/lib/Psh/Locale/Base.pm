package Psh::Locale::Base;

use strict;
use vars qw($VERSION);
use locale;

use POSIX qw(strftime);

$VERSION = '0.01';

my %alias_table= (
				  "de_de"   => "German",
				  "deutsch" => "German",
				  "de"      => "German");

sub init {

	my $lang= $ENV{LANG};

	# You can call the following a hack - we call
    # strftime to calculate dates to get the locale dependent
    # names - if anybody knows a better method to access
    # the locales installed on the system, feel free to change it

	@psh::mon= ();
	for( my $i=0; $i<12; $i++)
	{
		push( @psh::mon, strftime("%b",0,0,0,1,$i,99));
	}
	@psh::wday= ();
	for( my $i=0; $i<7; $i++)
	{
		push( @psh::wday, strftime("%a",0,0,0,1,1,99,$i));
	}

	# Use the default locale for defaults
	use Psh::Locale::Default;

	# Now try to use a locale module depending on LANG
	if( $lang and $lang ne "C" and $lang ne "POSIX") {
		$lang=ucfirst(lc($lang));
		$lang=$alias_table{$lang} if( exists $alias_table{$lang});
		eval "use Psh::Locale::$lang";
		#
		# We are reading the locale data simply as perl modules
		# A better way would be to maybe use Locale::PGetText
		# but that would again increase the requirements for
		# psh unnecessarily
	}
}



1;
__END__

=head1 NAME

Psh::Locale::Base - containing base code for I18N

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 AUTHOR

Markus Peter, warp@spin.de

=head1 SEE ALSO


=cut

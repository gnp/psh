package Psh::PerlEval;

#
# Must be on top of file before any "my" variables!
#
#
# array protected_eval(string EXPR, string FROM) 
#
# Evaluates "$Psh::eval_preamble EXPR", handling trapped signals and
# printing errors properly. The FROM string is passed on to
# handle_message to indicate where errors came from.
# 
# If EXPR ends in an ampersand, it is stripped and the eval is done in
# a forked copy of perl.
#
sub protected_eval
{
	#
	# Local package variables because lexical variables here mask
	# variables of the same name in main!!
	#
 
	local ($Psh::string, $Psh::from) = @_;
	local $Psh::redo_sentinel        = 0;

	# It's not possible to use fork_process for foreground perl
	# as we would lose all variables etc.

	{   #Dummy block to catch loop-control statements at outermost
		#level in EXPR 
		# First, protect against infinite loop
		# caused by redo:
		if ($Psh::redo_sentinel) { last; } 
		$Psh::redo_sentinel = 1;
		local $Psh::currently_active= -1;
		local @Psh::result= eval "$Psh::eval_preamble $Psh::string";

		if ( !$@ && @Psh::result &&
			 $#Psh::result==0 &&
			 $Psh::result[0] eq $Psh::string &&
			 $Psh::string=~ /^\s*\S+\s*$/ &&
			 $Psh::string!~ /^\s*(\'|\")\S+(\'|\")\s*$/ ) {
			#
			# Very whacky error handling
			# If you pass one word to perl and it's no function etc
			# it will simply return the word - that's not even a
			# bug actually but in case of psh it's annoying
			# so we try to detect these cases
			#

			Psh::Util::print_error_i18n('no_command',$Psh::string);
		}
		else {
			Psh::handle_message($@, $Psh::from);
		}
		return @Psh::result;
	}
	Psh::handle_message("Can't use loop control outside a block",
						$Psh::from);
	return undef;
}


#
# array variable_expansion (arrayref WORDS)
#
# For each element x of the array referred to by WORDS, substitute
# perl variables that appear in x respecting the quoting symbols ' and
# ", and return the array of substituted values. Substitutions inside
# quotes always return a single element in the resulting array;
# outside quotes, the result is split() and pushed on to the
# accumulating array of substituted values
#

sub variable_expansion
{
	local ($Psh::arref) = @_;
	local @Psh::retval  = ();
	local $Psh::word;

	for $Psh::word (@{$Psh::arref}) {
		if    ($Psh::word =~ m/^\'/) { push @Psh::retval, $Psh::word; }
		elsif ($Psh::word =~ m/^\"/) {
			local $Psh::word2= $Psh::word;
			$Psh::word2 =~ s/\\/\\\\/g;
			local $Psh::val = eval("$Psh::eval_preamble $Psh::word2");

			if ($@) { push @Psh::retval, $Psh::word; }
			else    { push @Psh::retval, "\"$Psh::val\""; }
		} else {
			local $Psh::word2= $Psh::word;
			$Psh::word2 =~ s/\\/\\\\/g;
			local $Psh::val = eval("$Psh::eval_preamble \"$Psh::word2\"");

			if ($@) { push @Psh::retval, $Psh::word; }
			else    {
				if ($]<5.005) {
					# TODO: Skip backslashes
					push @Psh::retval, split( /\s+/, $Psh::val);
				} else {
					push @Psh::retval, split(/(?<!\\)\s+/,$Psh::val);
				}
			}
		}
	}

	return @Psh::retval;
}

use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
require Exporter;
$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

@ISA= qw(Exporter);

@EXPORT= qw( );
@EXPORT_OK= qw( protected_eval variable_expansion);


1;


__END__

=head1 NAME

Psh::PerlEval - package containing perl evaluation codes


=head1 SYNOPSIS

	use Psh::PerlEval;

=head1 DESCRIPTION

TBD

=head1 AUTHOR

Glen Whitney I think..

=head1 SEE ALSO

=cut

# The following is for Emacs - I hope it won't annoy anyone
# but this could solve the problems with different tab widths etc
#
# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# c-basic-offset:4
# perl-indent-level:4
# End:

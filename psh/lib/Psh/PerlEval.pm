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

$Psh::PerlEval::current_package='main';

sub protected_eval
{
	#
	# Local package variables because lexical variables here mask
	# variables of the same name in main!!
	#
 
	local ($Psh::PerlEval::str, $Psh::PerlEval::from) = @_;
	local $Psh::PerlEval::redo_sentinel        = 0;

	# It's not possible to use fork_process for foreground perl
	# as we would lose all variables etc.

	{   #Dummy block to catch loop-control statements at outermost
		#level in EXPR 
		# First, protect against infinite loop
		# caused by redo:
		if ($Psh::PerlEval::redo_sentinel) { last; }
		$Psh::PerlEval::redo_sentinel = 1;
		local $Psh::currently_active= -1;
		$_= $Psh::PerlEval::lastscalar;
		@_= @Psh::PerlEval::lastarray;
		local @Psh::PerlEval::result= eval $Psh::eval_preamble.' package '.$Psh::PerlEval::current_package.'; '.$Psh::PerlEval::str;
		$Psh::PerlEval::lastscalar= $_;
		@Psh::PerlEval::lastarray= @_;

		if ( !$@ && @Psh::PerlEval::result &&
			 $#Psh::PerlEval::result==0 && $Psh::PerlEval::str &&
			 $Psh::PerlEval::result[0] &&
			 $Psh::PerlEval::result[0] eq $Psh::PerlEval::str &&
			 !Psh::is_number($Psh::PerlEval::str) &&
			 $Psh::PerlEval::str=~ /^\s*\S+\s*$/ &&
			 $Psh::PerlEval::str!~ /^\s*(\'|\")\S+(\'|\")\s*$/ ) {
			#
			# Very whacky error handling
			# If you pass one word to perl and it's no function etc
			# it will simply return the word - that's not even a
			# bug actually but in case of psh it's annoying
			# so we try to detect these cases
			#

			Psh::Util::print_error_i18n('no_command',$Psh::PerlEval::str);
			return undef;
		}
		else {
			if ($@) {
				Psh::handle_message($@, $Psh::PerlEval::from);
			}
		}
		return @Psh::PerlEval::result;
	}
	Psh::handle_message("Can't use loop control outside a block",
						$Psh::PerlEval::from);
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

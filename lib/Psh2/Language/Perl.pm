package Psh2::Language::Perl;

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

    {	    #Dummy block to catch loop-control statements at outermost
	#level in EXPR 
	# First, protect against infinite loop
	# caused by redo:
	if ($Psh::PerlEval::redo_sentinel) {
	    last;
	}
	$Psh::PerlEval::redo_sentinel = 1;
	local $Psh::currently_active= -1;
	$_= $Psh::PerlEval::lastscalar;
	@_= @Psh::PerlEval::lastarray;
	local @Psh::PerlEval::result= eval 'package main; '.$Psh::PerlEval::str;
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

#	    Psh::Util::print_error_i18n('no_command',$Psh::PerlEval::str);
	    return undef;
	} else {
	    if ($@) {
		print STDERR $@;
#		Psh::handle_message($@, $Psh::PerlEval::from);
	    }
	}
	return @Psh::PerlEval::result;
    }
#    Psh::handle_message("Can't use loop control outside a block",
#			$Psh::PerlEval::from);
    return undef;
}

## Critical part end

sub execute {
    my ($psh, $words)= @_;
    unshift @$words;

    protected_eval(Psh2::Parser::ungroup(join(' ',@$words)));
}

sub internal {
    return 1;
}

1;

package Psh2::Language::Perl;

#
# Must be on top of file before any "my" variables!
#
#
# array protected_eval(string EXPR, int preservevars) 
#
# Evaluates "$Psh::eval_preamble EXPR", handling trapped signals and
# printing errors properly. The FROM string is passed on to
# handle_message to indicate where errors came from.
#

sub protected_eval
{
    my $psh= shift; # psh object is supposed to be accessible

    #
    # Local package variables because lexical variables here mask
    # variables of the same name in main!!
    #
    local ($Psh2::Language::Perl::str, $Psh2::Language::Perl::preserve) = @_;
    local $Psh2::Language::Perl::redo_sentinel        = 0;

    # It's not possible to use fork_process for foreground perl
    # as we would lose all variables etc.

    {	    #Dummy block to catch loop-control statements at outermost
	#level in EXPR 
	# First, protect against infinite loop
	# caused by redo:
	if ($Psh2::Language::Perl::redo_sentinel) {
	    last;
	}
	$Psh2::Language::Perl::redo_sentinel = 1;
	#local $Psh::currently_active= -1;
        if ($Psh2::Language::Perl::preserve) {
            $_= $Psh2::Language::Perl::lastscalar;
            @_= @Psh2::Language::Perl::lastarray;
        }
	local @Psh2::Language::Perl::result= eval "package $psh->{current_package}; ".$Psh2::Language::Perl::str;
        if ($Psh2::Language::Perl::preserve) {
            $Psh2::Language::Perl::lastscalar= $_;
            @Psh2::Language::Perl::lastarray= @_;
        }

	if ( !$@ and @Psh2::Language::Perl::result and
	     $#Psh2::Language::Perl::result==0 and $Psh2::Language::Perl::str and
	     $Psh2::Language::Perl::result[0] and
	     $Psh2::Language::Perl::result[0] eq $Psh2::Language::Perl::str and
#	     !Psh::is_number($Psh2::Language::Perl::str) and
	     $Psh2::Language::Perl::str=~ /^\s*\S+\s*$/ and
	     $Psh2::Language::Perl::str!~ /^\s*(\'|\")\S+(\'|\")\s*$/ ) {
	    #
	    # Very whacky error handling
	    # If you pass one word to perl and it's no function etc
	    # it will simply return the word - that's not even a
	    # bug actually but in case of psh it's annoying
	    # so we try to detect these cases
	    #

#	    Psh::Util::print_error_i18n('no_command',$Psh2::Language::Perl::str);
	    return undef;
	} else {
	    if ($@) {
		print STDERR $@;
#		Psh::handle_message($@, $Psh2::Language::Perl::from);
	    }
	}
	return @Psh2::Language::Perl::result;
    }
#    Psh::handle_message("Can't use loop control outside a block",
#			$Psh2::Language::Perl::from);
    return undef;
}

## Critical part end

sub execute {
    my ($psh, $words)= @_;
    shift @$words;
    return defined protected_eval($psh,
                                  Psh2::Parser::ungroup(join(' ',@$words)),1);
}

sub internal {
    return 1;
}

1;

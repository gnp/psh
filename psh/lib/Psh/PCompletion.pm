#
#	$Id$
#
#	Copyright (c) 2000-2003 Hiroo Hayashi. All Rights Reserved.
#
#	This program is free software; you can redistribute it and/or
#	modify it under the same terms as Perl itself.

package Psh::PCompletion;

use strict;
use vars qw(%COMPSPEC %ACTION @ISA @EXPORT_OK);
require Exporter;
require Psh::Completion;
require Psh::Parser;

$Psh::PCompletion::LOADED=1; # tell other packages which optionally want to call us that we're here now

@ISA = qw(Exporter);
@EXPORT_OK = qw(compgen);

# for COMPSPEC actions
# borrowed from bash-2.04
sub CA_ALIAS		{ 1<<0; }
sub CA_ARRAYVAR		{ 1<<1; }
sub CA_BINDING		{ 1<<2; }
sub CA_BUILTIN		{ 1<<3; }
sub CA_COMMAND		{ 1<<4; }
sub CA_DIRECTORY	{ 1<<5; }
sub CA_DISABLED		{ 1<<6; }
sub CA_ENABLED		{ 1<<7; }
sub CA_EXPORT		{ 1<<8; }
sub CA_FILE		{ 1<<9; }
sub CA_FUNCTION		{ 1<<10; }
sub CA_HELPTOPIC	{ 1<<11; }
sub CA_HOSTNAME		{ 1<<12; }
sub CA_JOB		{ 1<<13; }
sub CA_KEYWORD		{ 1<<14; }
sub CA_RUNNING		{ 1<<15; }
sub CA_SETOPT		{ 1<<16; }
sub CA_SHOPT		{ 1<<17; }
sub CA_SIGNAL		{ 1<<18; }
sub CA_STOPPED		{ 1<<19; }
sub CA_USER		{ 1<<20; }
sub CA_VARIABLE		{ 1<<21; }
# psh original
sub CA_HASH		{ 1<<22; }

# pursing argments
BEGIN {
    %ACTION
	= (alias	=> CA_ALIAS,
	   arrayvar	=> CA_ARRAYVAR,	# Perl array variable
	   binding	=> CA_BINDING,
	   builtin	=> CA_BUILTIN,
	   command	=> CA_COMMAND,
	   directory	=> CA_DIRECTORY,
	   disabled	=> CA_DISABLED,	# not implemented yet
	   enabled	=> CA_ENABLED,	# not implemented yet
	   export	=> CA_EXPORT,
	   file		=> CA_FILE,
	   function	=> CA_FUNCTION,	# Perl function
	   helptopic	=> CA_HELPTOPIC,
	   hostname	=> CA_HOSTNAME,
	   job		=> CA_JOB,
	   keyword	=> CA_KEYWORD,
	   running	=> CA_RUNNING,
	   setopt	=> CA_SETOPT,	# not implemented yet
	   shopt	=> CA_SHOPT,	# not implemented yet
	   signal	=> CA_SIGNAL,
	   stopped	=> CA_STOPPED,
	   user		=> CA_USER,
	   variable	=> CA_VARIABLE,	# Perl variable
	   hashvar	=> CA_HASH,	# Perl hash variable
	  );
}

my($__line, $__start, $__cmd);

# global variables for compgen()
#use vars qw($__line $__start $__cmd);

# convert from bash (and ksh?) extglob to Perl regular expression
sub glob2regexp {
    local ($_) = @_;

    # ?(...), *(...), +(...) -> ()?, ()*, ()?
    s/([^\\])([?*+])\(([^)]*)\)/$1($3)$2/g; 
    s/^([?*+])\(([^)]*)\)/($2)$1/g; 

    # @(...) -> (...)
    s/([^\\])@\(([^)]*)\)/$1($2)/g;
    s/^@\(([^)]*)\)/($1)/g;

    # `!(...)' is not supported yet.

    # '.' -> '\.'
    s/([^\\])\./$1\\./g;
    s/^\./\\./g;

    # '*' -> '.*'
    s/([^\\)])\*/$1.*/g;
    s/^\*/.*/g;

    # '$' -> '\$'
    s/\$/\\\$/g;

    return '^' . $_ . '$';
}

sub pcomp_list {
    my ($cs, $text, $line, $start, $cmd) = @_;
    my @l;

	return () unless $line;
    my ($pretext) = substr($line, 0, $start) =~ /(\S*)$/;

    # actions
    if ($cs->{action} & CA_ALIAS and !$pretext) {
		if (Psh::Strategy::active('built_in')) {
			push(@l, grep { /^\Q$text/ } Psh::Support::Alias::get_alias_commands());
		}
    }
    if ($cs->{action} & CA_BINDING and !$pretext) {
	# only Term::ReadLine::Gnu 1.09 and later support funmap_names()
	# use `eval' for other versions
		eval { push(@l, grep { /^\Q$text/ } $Psh::term->funmap_names) };
		Psh::Util::print_debug_class('e',"Error: $@") if $@;
    }
    if ($cs->{action} & CA_BUILTIN  || $cs->{action} & CA_HELPTOPIC) {
		if (Psh::Strategy::active('built_in')) {
			push(@l, grep { /^\Q$text/ } Psh::Support::Builtins::get_builtin_commands());
		}
    }
    if ($cs->{action} & CA_COMMAND and !$pretext) {
		push(@l, Psh::Completion::cmpl_executable($text));
	}
    if ($cs->{action} & CA_DIRECTORY) {
		push(@l, Psh::Completion::cmpl_directories($pretext . $text));
	}
    if ($cs->{action} & CA_EXPORT and !$pretext) {
		push(@l, grep { /^\Q$text/ } keys %ENV);
    }
    if ($cs->{action} & CA_FILE) {
		my @f = Psh::Completion::cmpl_filenames($pretext . $text);
		if (defined $cs->{ffilterpat}) {
			my $pat = $cs->{ffilterpat};
			if ($pat =~ /^!/) {
				$pat = glob2regexp(substr($pat, 1));
				@f = grep(/$pat/, @f);
			} else {
				$pat = glob2regexp($pat);
				@f = grep(! /$pat/, @f);
			}
		}
		push(@l, @f);
		push(@l, Psh::Completion::cmpl_directories($pretext . $text));
	}
    if ($cs->{action} & CA_HOSTNAME and !$pretext) {
		push(@l, grep { /^\Q$text/ } Psh::Completion::bookmarks());
    }
    if ($cs->{action} & CA_KEYWORD and !$pretext) {
		push(@l, grep { /^\Q$text/ } @Psh::Completion::keyword);
    }
    if ($cs->{action} & CA_SIGNAL and !$pretext) {
		push(@l, grep { /^\Q$text/ } grep(!/^__/, keys %SIG));
    }
    if ($cs->{action} & CA_USER and !$pretext) {
		# Why are usernames in @user_completion prepended by `~'?
		push(@l, map { substr($_, 1) }
			 grep { /^~\Q$text/ } Psh::OS::get_all_users());
    }
    # job list
    if ($cs->{action} & CA_JOB and !$pretext) {
	push(@l,
	     map { $_->{call} }
	     grep { $_->{call} =~ /^\Q$text/ }
	      Psh::Joblist::list_jobs());
    }
    if ($cs->{action} & CA_RUNNING and !$pretext) {
	push(@l,
	     map { $_->{call} }
	     grep { $_->{running} && $_->{call} =~ /^\Q$text/ }
		 Psh::Joblist::list_jobs());
    }
    if ($cs->{action} & CA_STOPPED and !$pretext) {
	push(@l,
	     map { $_->{call} }
	     grep { ! $_->{running} && $_->{call} =~ /^\Q$text/ }
		 Psh::Joblist::list_jobs());
    }

    # Perl Symbol completions
#    printf "[$text,%08x]\n", $cs->{action};
	my $pkg = $Psh::PerlEval::current_package.'::';
    if ($cs->{action} & CA_VARIABLE and !$pretext) {
		no strict 'refs';
		push(@l, grep { /^\w+$/ && /^\Q$text/
						  && eval "defined \$$pkg$_" } keys %$pkg);
    }
    if ($cs->{action} & CA_ARRAYVAR and !$pretext) {
		my $sym;
		no strict 'refs';
		@l = grep {($sym = $pkg . $_, defined *$sym{ARRAY})
			   } keys %$pkg;
		push(@l,
			 grep { /^\Q$text/ }
			 grep { /^\w+$/ && ($sym = $pkg . $_, defined *$sym{ARRAY})
				} keys %$pkg);
    }
    if ($cs->{action} & CA_HASH and !$pretext) {
		my $sym;
		no strict 'refs';
		push(@l, grep { /^\w+$/ && /^\Q$text/
						  && ($sym = $pkg . $_, defined *$sym{HASH})
					  } keys %$pkg);
    }
    if ($cs->{action} & CA_FUNCTION and !$pretext) {
		my $sym;
		no strict 'refs';
		push(@l, grep { /^\w+$/ &&  /^\Q$text/
						  && ($sym = $pkg . $_, defined *$sym{CODE})
					  } keys %$pkg);
    }
	
    # -G glob
    # This does not work without modifying the specification of
    # Term::ReadLine::Perl::completion_function, which matches again
    # with globpattern.
#      if (defined $cs->{globpat}) {
#  	my $pat = glob2regexp($cs->{globpat});
#  	my $dir = $pretext || '.';
#  	opendir DIR, $dir
#  	    or warn "cannot open directory `$dir': $!\n", return ();
#  	my @d = readdir DIR;
#  	push(@l, grep(/$pat/, @d));
#  	closedir(DIR);
#      }

    # -W word list
    push(@l, grep { /^\Q$text/ } split(' ', $cs->{wordlist}))
	  if defined $cs->{wordlist} and !$pretext;

    # -F function
    if (defined $cs->{function} and !$pretext) {
		#	warn "[$text,$line,$start,$cmd]\n";
		$__line = $line; $__start = $start; $__cmd = $cmd; # for compgen()
		if ($cs->{function} =~/^(.*)\:\:[^:]+$/) {
			# Function is in a package, so try autoloading it
			my $package= $1;
			eval "require $package;";
		}
		my @t = eval {
			no strict 'refs';
			&{$cs->{functionpackage}.'::'.$cs->{function}}($text, $line, $start, $cmd);
		};
		if ($@) {
			warn $@;
		} else {
			push(@l, grep { /^\Q$text/ } @t);
		}
    }

    # -C command 
    if (defined $cs->{command} and !$pretext) {
		#	$ENV{COMP_LINE} = $line;
		#	$ENV{COMP_POINT} = $start;
		my $cmd = "$cs->{command}";
		# remove surrounding quotes
		$cmd =~ s/^\s*'(.*)'\s*$/$1/;
		$cmd =~ s/^\s*"(.*)"\s*$/$1/;
		push(@l, grep { chomp, /^\Q$text/ }
			 `$cmd "$text" "$line" "$start" "$cmd"`);
		warn "$0: $cs->{command}: command not found\n" if $?;
		#	$ENV{COMP_LINE} = $ENV{COMP_POINT} = undef;
    }
	
    # -X filter
    if (defined $cs->{filterpat}) {
		my $pat = $cs->{filterpat};
		#warn "[$pat";
		if ($pat =~ /^!/) {
			$pat = glob2regexp(substr($pat, 1));
			@l = grep(/$pat/, @l);
		} else {
			$pat = glob2regexp($pat);
			@l = grep(! /$pat/, @l);
		}
		#warn "->$pat]\n";
    }
	
    # -P prefix
    @l = map { $cs->{prefix} . $_ } @l if defined $cs->{prefix};
	
    # -S suffix
    @l = map { $_ . $cs->{suffix} } @l if defined $cs->{suffix};

	unshift @l,'';
    return @l;
}

########################################################################

sub pcomp_getopts {
    my $ar = $_[0];		# reference to an array of arguments
    my %cs;
    $cs{action} = 0;

    while (defined ($ar->[0]) and  $_ = $ar->[0], /^-/) {
	shift @{$ar};
	last if  /^--$/;
	if (/^-a/) {
	    $cs{action} |= CA_ALIAS;
	} elsif (/^-b/) {
	    $cs{action} |= CA_BUILTIN;
	} elsif (/^-c/) {
	    $cs{action} |= CA_COMMAND;
	} elsif (/^-d/) {
	    $cs{action} |= CA_DIRECTORY;
	} elsif (/^-e/) {
	    $cs{action} |= CA_EXPORT;
	} elsif (/^-f/) {
	    $cs{action} |= CA_FILE;
	} elsif (/^-j/) {
	    $cs{action} |= CA_JOB;
	} elsif (/^-k/) {
	    $cs{action} |= CA_KEYWORD;
	} elsif (/^-u/) {
	    $cs{action} |= CA_USER;
	} elsif (/^-v/) {
	    $cs{action} |= CA_VARIABLE;
	} elsif (/^-o/) {
		$cs{option}    = Psh::Parser::unquote(shift @{$ar});
	} elsif (/^-A/) {
	    $_ = Psh::Parser::unquote(shift @{$ar}) || return undef;
	    $cs{action} |= $ACTION{$_};
	} elsif (/^-G/) {
	    $cs{globpat}   = Psh::Parser::unquote(shift @{$ar});
	} elsif (/^-W/) {
	    $cs{wordlist}  = Psh::Parser::unquote(shift @{$ar});
	} elsif (/^-C/) {
	    $cs{command}   = Psh::Parser::unquote(shift @{$ar});
	} elsif (/^-F/) {
	    $cs{function}  = Psh::Parser::unquote(shift @{$ar});
		$cs{function_package}= $Psh::PerlEval::current_package;
	} elsif (/^-X/) {
	    $cs{filterpat} = Psh::Parser::unquote(shift @{$ar});
	} elsif (/^-x/) {	# psh specific (at least now)
	    $cs{ffilterpat} = Psh::Parser::unquote(shift @{$ar});
	} elsif (/^-P/) {
	    $cs{prefix}    = Psh::Parser::unquote(shift @{$ar});
	} elsif (/^-S/) {
	    $cs{suffix}    = Psh::Parser::unquote(shift @{$ar});
	} elsif (/^-p/) {
	    $cs{print}  = 1;
	} elsif (/^-r/) {
	    $cs{remove} = 1;
	} else {
	    return undef;
	}
    }
    return \%cs;
}

sub _redir_op {
    local $_ = shift;
    return 0 if /'[<>]'/;
    return 1 if /[<>]/;
    return 0;
}

sub redir_test {
    my($cur, $prev) = @_;

    if (_redir_op($cur)) {
        return compgen('-f', $cur);
    } elsif (_redir_op($prev)) {
        return compgen('-f', $cur);
    } else {
        return ();
    }
}

sub compgen {
	if (!@_ or !$_[0]) {
		usage_compgen();
		return undef;
	}
    my $cs = pcomp_getopts($_[0]) or usage_compgen(), return ;
    @_ = @{$_[0]};
    usage_compgen() if $cs->{print} or $cs->{remove} or $#_ > 1;

    pcomp_list($cs, $_[0] || '', $__line, $__start, $__cmd);
}

sub usage_compgen {
    print STDERR <<EOM;
compgen [-abcdefjkvu] [-A ACTION] [-G GLOBPAT] [-W WORDLIST]
	[-P PREFIX] [-S SUFFIX] [-X FILTERPAT] [-x FILTERPAT]
	[-F FUNCTION] [-C COMMAND] [WORD]
EOM
}

package main;

# compgen() routine is called by function which is assigned by `-F' option
# of complete command.
sub compgen {
    Psh::PCompletion::compgen(\@_);
}

1;
__END__

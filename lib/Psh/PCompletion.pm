#
#	$Id$
#
#	Copyright (c) 2000-2001 Hiroo Hayashi. All Rights Reserved.
#
#	This program is free software; you can redistribute it and/or
#	modify it under the same terms as Perl itself.

package Psh::PCompletion;

use strict;
use vars qw(%COMPSPEC %ACTION @ISA @EXPORT_OK);
require Exporter;

@ISA = qw(Exporter);
@EXPORT_OK = qw(pcomp_getopts %ACTION %COMPSPEC compgen redir_test);

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

	# Simulate old @netprograms support
	my $tmp= {'action'=>CA_HOSTNAME};
	%COMPSPEC=('ftp'=>$tmp,'ncftp'=>$tmp,'telnet'=>$tmp,'traceroute'=>$tmp,
			   'ssh'=>$tmp,'ssh1'=>$tmp,'ssh2'=>$tmp,'ping'=>$tmp);
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

    my ($pretext) = substr($line, 0, $start) =~ /(\S*)$/;

    # actions
    if ($cs->{action} & CA_ALIAS) {
	push(@l, grep { /^\Q$text/ } &Psh::Builtins::get_alias_commands);
    }
    if ($cs->{action} & CA_BINDING) {
	# only Term::ReadLine::Gnu 1.09 and later support funmap_names()
	# use `eval' for other versions
	eval { push(@l, grep { /^\Q$text/ } $Psh::term->funmap_names) };
    }
    if ($cs->{action} & CA_BUILTIN  || $cs->{action} & CA_HELPTOPIC) {
	push(@l, grep { /^\Q$text/ } &Psh::Builtins::get_builtin_commands);
    }
    if ($cs->{action} & CA_COMMAND) {
	push(@l, Psh::Completion::cmpl_executable($text));
    }
    if ($cs->{action} & CA_DIRECTORY) {
	push(@l, Psh::Completion::cmpl_directories($pretext . $text));
    }
    if ($cs->{action} & CA_EXPORT) {
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
    if ($cs->{action} & CA_HOSTNAME) {
		push(@l, grep { /^\Q$text/ } Psh::Completion::bookmarks());
    }
    if ($cs->{action} & CA_KEYWORD) {
		push(@l, grep { /^\Q$text/ } @Psh::Completion::keyword);
    }
    if ($cs->{action} & CA_SIGNAL) {
		push(@l, grep { /^\Q$text/ } grep(!/^__/, keys %SIG));
    }
    if ($cs->{action} & CA_USER) {
		# Why are usernames in @user_completion prepended by `~'?
		push(@l, map { substr($_, 1) }
			 grep { /^~\Q$text/ } @Psh::Completion::user_completions);
    }
    # job list
    if ($cs->{action} & CA_JOB) {
	push(@l,
	     map { $_->{call} }
	     grep { $_->{call} =~ /^\Q$text/ }
	     @{$Psh::joblist->{jobs_order}});
    }
    if ($cs->{action} & CA_RUNNING) {
	push(@l,
	     map { $_->{call} }
	     grep { $_->{running} && $_->{call} =~ /^\Q$text/ }
	     @{$Psh::joblist->{jobs_order}});
    }
    if ($cs->{action} & CA_STOPPED) {
	push(@l,
	     map { $_->{call} }
	     grep { ! $_->{running} && $_->{call} =~ /^\Q$text/ }
	     @{$Psh::joblist->{jobs_order}});
    }

    # Perl Symbol completions
#    printf "[$text,%08x]\n", $cs->{action};
    my $pkg = '::';		# assume main package now.  cf. cmpl_symbol()
    if ($cs->{action} & CA_VARIABLE) {
	no strict 'refs';
	push(@l, grep { /^\w+$/ && /^\Q$text/
			    && eval "defined \$$pkg$_" } keys %$pkg);
    }
    if ($cs->{action} & CA_ARRAYVAR) {
	my $sym;
	no strict 'refs';
	@l = grep {($sym = $pkg . $_, defined *$sym{ARRAY})
		} keys %$pkg;
	push(@l,
	     grep { /^\Q$text/ }
	     grep { /^\w+$/ && ($sym = $pkg . $_, defined *$sym{ARRAY})
		    } keys %$pkg);
    }
    if ($cs->{action} & CA_HASH) {
	my $sym;
	no strict 'refs';
	push(@l, grep { /^\w+$/ && /^\Q$text/
			    && ($sym = $pkg . $_, defined *$sym{HASH})
			} keys %$pkg);
    }
    if ($cs->{action} & CA_FUNCTION) {
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
	if defined $cs->{wordlist};

    # -F function
    if (defined $cs->{function}) {
#	warn "[$text,$line,$start,$cmd]\n";
	$__line = $line; $__start = $start; $__cmd = $cmd; # for compgen()
	my @t = eval { package main;
		       no strict 'refs';
		       &{$cs->{function}}($text, $line, $start, $cmd);
		   };
	if ($@) {
	    warn $@;
	} else {
	    push(@l, grep { /^\Q$text/ } @t);
	}
    }

    # -C command 
    if (defined $cs->{command}) {
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

    return @l;
}

########################################################################

sub unquote {
    local($_) = @_;
    s/^'(.*)'$/$1/;
    s/^"(.*)"$/$1/;
    return $_;
}

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
	} elsif (/^-A/) {
	    $_ = unquote(shift @{$ar}) || return undef;
	    $cs{action} |= $ACTION{$_};
	} elsif (/^-G/) {
	    $cs{globpat}   = unquote(shift @{$ar});
	} elsif (/^-W/) {
	    $cs{wordlist}  = unquote(shift @{$ar});
	} elsif (/^-C/) {
	    $cs{command}   = unquote(shift @{$ar});
	} elsif (/^-F/) {
	    $cs{function}  = unquote(shift @{$ar});
	} elsif (/^-X/) {
	    $cs{filterpat} = unquote(shift @{$ar});
	} elsif (/^-x/) {	# psh specific (at least now)
	    $cs{ffilterpat} = unquote(shift @{$ar});
	} elsif (/^-P/) {
	    $cs{prefix}    = unquote(shift @{$ar});
	} elsif (/^-S/) {
	    $cs{suffix}    = unquote(shift @{$ar});
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

=head1 NAME

Psh::PCompletion - containing the programmable completion routines of
psh.

=head1 SYNOPSIS

=head1 DESCRIPTION

This module provides the programmable completion function almost
compatible with one of bash-2.04 and/or later.  The following document
is based on the texinfo file of bash-2.04-beta5.

=head2 Programmable Completion
=======================

When word completion is attempted for an argument to a command for
which a completion specification (a COMPSPEC) has been defined using
the B<complete> builtin (See L<Programmable Completion Builtins>.),
the programmable completion facilities are invoked.

First, the command name is identified.  If a compspec has been defined
for that command, the compspec is used to generate the list of
possible completions for the word.  If the command word is a full
pathname, a compspec for the full pathname is searched for first.  If
no compspec is found for the full pathname, an attempt is made to find
a compspec for the portion following the final slash.

Once a compspec has been found, it is used to generate the list of
matching words.  If a compspec is not found, the default Psh
completion described above (Where is it described?) is performed.

First, the actions specified by the compspec are used.  Only matches
which are prefixed by the word being completed are returned.  When the
B<-f> or B<-d> option is used for filename or directory name
completion, the shell variable B<FIGNORE> is used to filter the
matches.  See L<ENVIRONMENT VARIABLES> for a description of
B<FIGNORE>.

Any completions specified by a filename expansion pattern to the B<-G>
option are generated next.  The words generated by the pattern need
not match the word being completed.  The B<GLOBIGNORE> shell variable
is not used to filter the matches, but the B<FIGNORE> shell variable
is used.

Next, the string specified as the argument to the B<-W> option is
considered.  The string is first split using the characters in the
B<IFS> special variable as delimiters.  Shell quoting is honored.
Each word is then expanded using brace expansion, tilde expansion,
parameter and variable expansion, command substitution, arithmetic
expansion, and pathname expansion, as described above (Where is it
described?).  The results are split using the rules described above
(Where is it described?).  No filtering against the word being
completed is performed.

After these matches have been generated, any shell function or command
specified with the B<-F> and B<-C> options is invoked.  When the
function or command is invoked, the first argument is the word being
completed, the second argument is the current command line, the third
argument is the index of the current cursor position relative to the
beginning of the current command line, and the fourth argument is the
name of the command whose arguments are being completed.  If the
current cursor position is at the end of the current command, the
value of the third argument is equal to the length of the second
argument string.

No filtering of the generated completions against the word being
completed is performed; the function or command has complete freedom
in generating the matches.

Any function specified with B<-F> is invoked first.  The function may
use any of the shell facilities, including the B<compgen> builtin
described below (See L<Programmable Completion Builtins>.), to
generate the matches.  It returns a array including the possible
completions.  For example;

	sub _foo_func {
	    my ($cur, $line, $start, $cmd) = @_;
	    ...
	    return @possible_completions;
	}
	complete -F _foo_func bar

Next, any command specified with the B<-C> option is invoked in an
environment equivalent to command substitution.  It should print a list
of completions, one per line, to the standard output.  Backslash may be
used to escape a newline, if necessary.

After all of the possible completions are generated, any filter
specified with the B<-X> option is applied to the list.  The filter is
a pattern as used for pathname expansion; a C<&> in the pattern is
replaced with the text of the word being completed.  A literal C<&>
may be escaped with a backslash; the backslash is removed before
attempting a match.  Any completion that matches the pattern will be
removed from the list.  A leading C<!> negates the pattern; in this
case any completion not matching the pattern will be removed.

Finally, any prefix and suffix specified with the B<-P> and B<-S>
options are added to each member of the completion list, and the
result is returned to the Readline completion code as the list of
possible completions.

If a compspec is found, whatever it generates is returned to the
completion code as the full set of possible completions.  The default
Bash completions are not attempted, and the Readline default of
filename completion is disabled.

=head2 Programmable Completion Builtins
================================

A builtin commands B<complete> and a builtin Perl function B<compgen>
are available to manipulate the programmable completion facilities.

=over 4

=item B<compgen>

	compgen [OPTION] [WORD]

Generate possible completion matches for I<WORD> according to the
I<OPTION>s, which may be any option accepted by the B<complete> builtin
with the exception of B<-p> and B<-r>, and write the matches to the
standard output.  When using the B<-F> or B<-C> options, the various
shell variables set by the programmable completion facilities, while
available, will not have useful values.

The matches will be generated in the same way as if the programmable
completion code had generated them directly from a completion
specification with the same flags.  If I<WORD> is specified, only
those completions matching I<WORD> will be displayed.

The return value is true unless an invalid option is supplied, or no
matches were generated.

=item B<complete>

	complete [-abcdefjkvu] [-A ACTION] [-G GLOBPAT] [-W WORDLIST]
		 [-P PREFIX] [-S SUFFIX] [-X FILTERPAT] [-x FILTERPAT]
		 [-F FUNCTION] [-C COMMAND] NAME [NAME ...]
	complete -pr [NAME ...]

Specify how arguments to each I<NAME> should be completed.  If the
B<-p> option is supplied, or if no options are supplied, existing
completion specifications are printed in a way that allows them to be
reused as input.  The B<-r> option removes a completion specification
for each I<NAME>, or, if no I<NAME>s are supplied, all completion
specifications.

The process of applying these completion specifications when word
completion is attempted is described above (See L<Programmable
Completion>.).

Other options, if specified, have the following meanings.  The
arguments to the B<-G>, B<-W>, and B<-X> options (and, if necessary,
the B<-P> and B<-S> options) should be quoted to protect them from
expansion before the B<complete> builtin is invoked.

=over 4

=item B<-A> I<ACTION>

The I<ACTION> may be one of the following to generate a list of
possible completions:

=over 4

=item B<alias>

Alias names.  May also be specified as B<-a>.

=item B<arrayvar>

Names of Perl array variable names.

=item B<binding>

Readline key binding names.

=item B<builtin>

Names of shell builtin commands.  May also be specified as B<-b>.

=item B<command>

Command names.  May also be specified as B<-c>.

=item B<directory>

Directory names.  May also be specified as B<-d>.

=item B<disabled>

Names of disabled shell builtins (not implemented yet.).

=item B<enabled>

Names of enabled shell builtins (not implemented yet.).

=item B<export>

Names of exported shell variables.  May also be specified as B<-e>.

=item B<file>

File names.  May also be specified as B<-f>.

=item B<function>

Names of Perl functions.

=item B<hashvar>

Names of Perl hash variable names.

=item B<helptopic>

Help topics as accepted by the `help' builtin.

=item B<hostname>

Hostnames.

=item B<job>

Job names, if job control is active.  May also be specified as B<-j>.

=item B<keyword>

Shell reserved words.  May also be specified as B<-k>.

=item B<running>

Names of running jobs, if job control is active.

=item B<setopt>

Valid arguments for the B<-o> option to the B<set> builtin (not
implemented yet.).

=item B<shopt>

Shell option names as accepted by the B<shopt> builtin (not
implemented yet.).

=item B<signal>

Signal names.

=item B<stopped>

Names of stopped jobs, if job control is active.

=item B<user>

User names.  May also be specified as B<-u>.

=item B<variable>

Names of all Perl variables.  May also be specified as B<-v>.

=back

=item B<-G> I<GLOBPAT>

The filename expansion pattern I<GLOBPAT> is expanded to generate the
possible completions.

=item B<-W> I<WORDLIST>

The I<WORDLIST> is split using the characters in the B<IFS> special
variable as delimiters, and each resultant word is expanded.  The
possible completions are the resultant list.

=item B<-C> I<COMMAND>

I<COMMAND> is executed in a subshell environment, and its output is
used as the possible completions.

=item B<-F> I<FUNCTION>

The shell function I<FUNCTION> is executed in the current Perl shell
environment.  When it finishes, the possible completions are retrieved
from the array which the function returns.

=item B<-X> I<FILTERPAT>

I<FILTERPAT> is a pattern as used for filename expansion.  It is
applied to the list of possible completions generated by the preceding
options and arguments, and each completion matching I<FILTERPAT> is
removed from the list.  A leading C<!> in I<FILTERPAT> negates the
pattern; in this case, any completion not matching I<FILTERPAT> is
removed.

=item B<-x> I<FILTERPAT>

Similar to the B<-X> option above, except it is applied to only
filenames not to directory names etc.

=item B<-P> I<PREFIX>

I<PREFIX> is added at the beginning of each possible completion after
all other options have been applied.

=item B<-S> I<SUFFIX>

I<SUFFIX> is appended to each possible completion after all other
options have been applied.

=back

The return value is true unless an invalid option is supplied, an
option other than B<-p> or B<-r> is supplied without a I<NAME>
argument, an attempt is made to remove a completion specification for
a I<NAME> for which no specification exists, or an error occurs adding
a completion specification.

=back

=head1 AUTHOR

Hiroo Hayashi, hiroo.hayashi@computer.org

=head1 SEE ALSO

info manual of bash-2.04 and/or later

=head1 EXAMPLE

F<complete_example> in the Psh distribution shows you many examples of
the usage of programmable completion.

	source complete-examples

=cut

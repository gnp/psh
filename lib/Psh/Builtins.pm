#! /usr/local/bin/perl -w

=head1 NAME

Psh::Builtins - package for Psh builtins, possibly loading them as needed

=head1 SYNOPSIS

  use Psh::Builtins;

=head1 DESCRIPTION

Psh::Builtins currently contains only the hardcoded builtins of Perl Shell,
but may later on be extended to load them on the fly from separate
modules.

=head2 Builtins

=over 4

=cut

package Psh::Builtins;

###############################################################
# Short description:
# (I included it here because it's not supposed to be in the
#  user documentation)
#
# There are x types of functions in this package
# 1) bi_builtin functions in Psh::Builtins - these are
#    the builtin definitions
# 2) bi_builtin functions in Psh::Builtins::Fallback - these
#    are last resort fallback builtins for non-unix platforms
#    so psh can offer minimum functionality for them even without
#    stuff like GNU fileutils etc.
# 3) cmpl_builtin functions in Psh::Builtins - these are
#    functions called by the TAB completer to complete text for
#    the builtins. They return a list. The first element of the
#    list is a flag which specifies wether the completions should
#    add to the standard completions or replace them. See the code
#    for more information
# 4) Utility and internal functions
###############################################################

use strict;
use vars qw($VERSION %aliases @dir_stack $dir_stack_pos);

use Config;
use Psh::Util qw(:all print_list);
use Psh::OS;
use File::Spec;

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

my $PS=$Psh::OS::PATH_SEPARATOR;

%Psh::array_exports=('PATH'=>$PS,'CLASSPATH'=>$PS,'LD_LIBRARY_PATH'=>$PS,
					 'FIGNORE'=>$PS,'CDPATH'=>$PS,'LS_COLORS'=>':');

@dir_stack= (Psh::OS::getcwd_psh());
$dir_stack_pos=0;


#
# string _do_setenv(string command)
#
# command is of the form "VAR VALUE" or "VAR = VALUE" or "VAR"; sets
# $ENV{VAR} to "VALUE" in the first two cases, or to "$VAR" in the
# third case unless $VAR is undefined. Used by the setenv and export
# builtins. Returns VAR (which is a string with no $).

sub _do_setenv
{
	my $arg = shift;
	if( $arg=~ /^\s*(\w+)(\s+|\s*=\s*)(.+)/ ) {
		my $var= $1;
		my $value= $3;
		if( $value=~ /^\'(.*)\'\s*$/ ) {
			# If single quotes were used, do not interpret
			# variables
			$ENV{$var}=$1;
		} else {
			$var =~ s/^\$//;
			if ($value=~ /^\"(.*)\"/) {
				$value=$1;
			}
			# Use eval so that variables may appear on RHS
			# ($value); use protected_eval so that lexicals
			# in this file don't shadow package variables
			Psh::protected_eval("\$ENV{$var}=\"$value\"", 'do_setenv');
		}
		return $var;
	} elsif( $arg=~ /(\w+)/ ) {
		my $var= $1;
		$var =~ s/^\$//;
		Psh::protected_eval("\$ENV{$var}=\$$var if defined(\$$var);",
			       'do_setenv');
		return $var;
	}
	return '';
}

=item * C<setenv NAME [=] VALUE>

Sets the environment variable NAME to VALUE.

=cut

sub bi_setenv
{
	my $var = _do_setenv(@_);
	print_error_i18n('usage_setenv') if !$var;
	return undef;
}

=item * C<delenv NAME [NAME2 NAME3 ...]>

Deletes the names environment variables.

=cut

sub bi_delenv
{
	my @args= split(' ',$_[0]);
	if( !@args) {
		print_error_i18n('usage_delenv');
		return undef;
	}
	foreach my $var ( @args) {
		my @result = Psh::protected_eval("tied(\$$var)");
		my $oldtie = $result[0];
		if (defined($oldtie)) {
			Psh::protected_eval("untie(\$$var)");
		}
		delete($ENV{$var});
	}
}

=item * C<export VAR [=VALUE]>

Just like setenv, below, except that it also ties the variable (in the
Perl sense) so that subsequent changes to the variable automatically
affect the environment. Variables who are lists and appear in
C<%Psh::array_exports> will also by tied to the array of the same name.
Note that the variable must be specified without any Perl specifier
like C<$> or C<@>.

=cut

sub bi_export
{
	my $var = _do_setenv(@_);
	if ($var) {
		my @result = Psh::protected_eval("tied(\$$var)");
		my $oldtie = $result[0];
		if (defined($oldtie)) {
			if (ref($oldtie) ne 'Env') {
				print_warning_i18n('bi_export_tied',$var,$oldtie);
			}
		} else {
			Psh::protected_eval("use Env '$var';");
			if( exists($Psh::array_exports{$var})) {
				eval "use Env::Array;";
				if( ! $@) {
					Psh::protected_eval("use Env::Array qw($var $Psh::array_exports{$var});",'hide');
				}
			}
		}
	} else {
		print_error_i18n('usage_export');
	}
	return undef;
}


=item * C<cd DIR>

Change the working directory to DIR or home if DIR is not specified.
The special DIR "-" is interpreted as "return to the previous
directory".

=cut

$ENV{OLDPWD}= $dir_stack[0];

sub bi_cd
{
	my $in_dir = shift || Psh::OS::get_home_dir();
	my $explicit=0;

	if ($in_dir=~/^[+-](\d+)$/) {
		my $tmp_pos=$dir_stack_pos-int($in_dir);
		if ($tmp_pos<0) {
			# TODO: Error handling
		} elsif ($tmp_pos>$#dir_stack) {
			# TODO: Error handling
		} else {
			$in_dir=$dir_stack[$tmp_pos];
			$dir_stack_pos=$tmp_pos;
		}
	} elsif ($in_dir eq '-') {
		if (@dir_stack>1) {
			if ($dir_stack_pos==0) {
				$in_dir=$dir_stack[1];
				$dir_stack_pos=1;
			} else {
				$in_dir=$dir_stack[0];
				$dir_stack_pos=0;
			}
		}
	} elsif ($in_dir=~ /^\%(\d+)$/) {
		my $tmp_pos=$1;
		if ($tmp_pos>$#dir_stack) {
			# TODO: Error handling
		} else {
			$in_dir=$dir_stack[$tmp_pos];
			$dir_stack_pos=$tmp_pos;
		}
	} else {
		$explicit=1 unless $in_dir eq $dir_stack[0];
		# Don't push the same value again
		$dir_stack_pos=0;
	}
	my $dirpath='.';

	if ($ENV{CDPATH} && !File::Spec->file_name_is_absolute($in_dir)) {
		$dirpath.=$ENV{CDPATH};
	}

	foreach my $cdbase (split $PS,$dirpath) {
		my $dir= $in_dir;
		if( $cdbase eq '.') {
			$dir = Psh::Util::abs_path($dir);
		} else {
			$dir = Psh::Util::abs_path(File::Spec->catdir($cdbase,$dir));
		}

		if ((-e $dir) and (-d _)) {
			if (-x _) {
				$ENV{OLDPWD}= $ENV{PWD};
				unshift @dir_stack, $dir if $explicit;
				CORE::chdir $dir;
				$ENV{PWD}=$dir;
				return 0;
			} else {
				print_error_i18n('perm_denied',$in_dir,$Psh::bin);
				return 1;
			}
		}
	}
	print_error_i18n('no_such_dir',$in_dir,$Psh::bin);
	return 1;
}

sub cmpl_cd {
	my( $text, $pre) = @_;
	return 1,Psh::Completion::cmpl_directories($pre.$text);
}

=item * C<alias [NAME [=] REPLACEMENT]> 

Add C<I<NAME>> as a built-in so that NAME <REST_OF_LINE> will execute
exactly as if REPLACEMENT <REST_OF_LINE> had been entered. For
example, one can execute C<alias ls ls -F> to always supply the B<-F>
option to "ls". Note the built-in is defined to avoid recursion
here.

With no arguments, prints out a list of the current aliases.
With only the C<I<NAME>> argument, prints out a definition of the
alias with that name.

=cut

%aliases = ();
	
sub bi_alias
{
	my $line = shift;
	my ($command, $firstDelim, @rest) = Psh::Parser::decompose('([ \t\n=]+)', $line, undef, 0);
	my $text = join('',@rest); # reconstruct everything after the
	# first delimiter, sans quotes
	if (($command eq "") && ($text eq "")) {
		my $wereThereSome = 0;
		for $command (sort keys %aliases) {
			my $aliasrhs = $aliases{$command};
			$aliasrhs =~ s/\'/\\\'/g;
			print_out("alias $command='$aliasrhs'\n");
			$wereThereSome = 1;
		}
		if (!$wereThereSome) {
			print_out_i18n('bi_alias_none');
		}
	} elsif( $text eq '') {
		my $aliasrhs = $aliases{$command};
		$aliasrhs =~ s/\'/\\\'/g;
		print_out("alias $command='$aliasrhs'\n");
	} elsif ($text eq '-a') {
		print_error_i18n('bi_alias_cant_a');
	} else {
		$aliases{$command} = $text;
	}
	return 0;
}

=item * C<unalias NAME | -a | all]>

Removes the alias with name <C<I<NAME>> or all aliases if either <C<I<-a>>
(for bash compatibility) or <C<I<all>> is specified.

=cut

sub bi_unalias {
	my $name= shift;
	if( ($name eq '-a' || $name eq 'all') and !_is_aliased($name) ) {
		%aliases= ();
	} elsif( _is_aliased($name)) {
		delete($aliases{$name});
	} else {
		print_error_i18n('unalias_noalias', $name);
		return 1;
	}
	return 0;
}


sub cmpl_unalias {
	my $text= shift;
	return (1,grep { Psh::Util::starts_with($_,$text) } get_alias_commands());
}


# 
# bool _is_aliased( string COMMAND )
#
# returns TRUE if COMMAND is aliased:

sub _is_aliased {
       my $command = shift;
       if (exists($aliases{$command})) { return 1; }
       return 0;
}

#####################################################################
# Utility functions
#####################################################################

# Returns a list of aliases commands
sub get_alias_commands {
	return keys %aliases;
}

# Returns a list of builtins
sub get_builtin_commands {
	no strict 'refs';
	my @list= ();
	my @sym = keys %{*{'Psh::Builtins::'}};
	for my $sym (sort @sym) {
		push @list, substr($sym,3) if substr($sym,0,3) eq 'bi_' &&
			ref *{'Psh::Builtins::'.$sym}{CODE} eq 'CODE';
	}
	push @list, keys %Psh::built_ins;
	return @list;
}

sub build_autoload_list {
	%Psh::built_ins= ();

	foreach my $tmp (@INC) {
		my $tmpdir= File::Spec->catdir($tmp,'Psh','Builtins');
		my @files= Psh::OS::glob('*.pm',$tmpdir);
		foreach( @files) {
			s/\.pm$//;
			$_= lc($_);
			$Psh::built_ins{$_}= 1;
		}
	}
}

1;

__END__

=back

=head1 AUTHOR

the Psh team

=head1 SEE ALSO

L<psh>

=cut

# The following is for Emacs - I hope it won't annoy anyone
# but this could solve the problems with different tab widths etc
#
# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# c-basic-offset:4
# perl-indent-level:4
# perl-label-offset:0
# End:



package Psh2::Builtins::Cd;

use strict;

=item * C<cd DIR>

Change the working directory to DIR or home if DIR is not specified.
The special DIR "-" is interpreted as "return to the previous
directory".

C<cd %num> will jump to a certain directory in the stack (See also
builtin C<dirs>).

C<cd +num> and C<cd -num> will go forward/backward in the directory
stack.

=cut

sub execute {
    my ($psh, $words)= @_;
    shift @$words;
    my $in_dir= join(' ',@$words);
    $in_dir ||= $ENV{HOME};

    my $explicit= 0;

    if (@{$psh->{dirstack}}==0) {
	push @{$psh->{dirstack}}, $ENV{PWD};
    }

    if ($in_dir=~/^[+-](\d+)$/) {
	my $tmp_pos= $psh->{dirstack_pos}- int($in_dir);
	if ($tmp_pos<0) {
	    # TODO: Error handling
	} elsif ($tmp_pos>=@{$psh->{dirstack}}) {
	    # TODO: Error handling
	} else {
	    $in_dir= $psh->{dirstack}[$tmp_pos];
	    $psh->{dirstack_pos}= $tmp_pos;
	}
    } elsif ($in_dir eq '-') {
	if (@{$psh->{dirstack}}>1) {
	    if ($psh->{dirstack_pos}==0) {
		$in_dir= $psh->{dirstack}[1];
		$psh->{dirstack_pos}= 1;
	    } else {
		$in_dir= $psh->{dirstack}[0];
		$psh->{dirstack_pos}= 0;
	    }
	}
    } elsif ($in_dir=~ /^\%(\d+)$/) {
	my $tmp_pos=$1;
	if ($tmp_pos>= @{$psh->{dirstack}}) {
	    # TODO: Error handling
	} else {
	    $in_dir= $psh->{dirstack}[$tmp_pos];
	    $psh->{dirstack_pos}= $tmp_pos;
	}
    } else {
	$explicit=1 unless $in_dir eq $psh->{dirstack}[0];
	# Don't push the same value again
	$psh->{dirstack_pos}= 0;
    }
    my $dirpath='';

    if ($ENV{CDPATH} and !$psh->file_name_is_absolute($in_dir)) {
	$dirpath=$ENV{CDPATH};
    }

    foreach my $cdbase (split ($psh->path_separator(),$dirpath), '.') {
	my $dir= $in_dir;
	if( $cdbase eq '.') {
	    $dir = $psh->abs_path($dir);
	} else {
	    $dir = $psh->abs_path($psh->catdir($cdbase,$dir));
	}
	if ($dir and (-e $dir) and (-d _)) {
	    if (-x _) {
		$ENV{OLDPWD}= $ENV{PWD};
		unshift @{$psh->{dirstack}}, $dir if $explicit;
		CORE::chdir $dir;
		$ENV{PWD}=$dir;
		return 1;
	    } else {
		$psh->printerr(sprintf($psh->gt('cd: permission denied: %s'),
				      $in_dir)."\n");
		return 0;
	    }
	}
    }
    $psh->printerr(sprintf($psh->gt('cd: no such dir: %s'), $in_dir)."\n");
    return 0;
}

1;

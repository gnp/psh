package Psh::Builtins::Cd;

require Psh::Support::Dirs;
require Psh::Completion;
require Psh::OS;

=item * C<cd DIR>

Change the working directory to DIR or home if DIR is not specified.
The special DIR "-" is interpreted as "return to the previous
directory".

=cut

sub bi_cd
{
	my $in_dir = shift || Psh::OS::get_home_dir();
	my $explicit=0;
	unless (@Psh::Support::Dirs::stack) {
		push @Psh::Support::Dirs::stack, $ENV{PWD};
	}

	if ($in_dir=~/^[+-](\d+)$/) {
		my $tmp_pos=$Psh::Support::Dirs::stack_pos-int($in_dir);
		if ($tmp_pos<0) {
			# TODO: Error handling
		} elsif ($tmp_pos>$#Psh::Support::Dirs::stack) {
			# TODO: Error handling
		} else {
			$in_dir=$Psh::Support::Dirs::stack[$tmp_pos];
			$Psh::Support::Dirs::stack_pos=$tmp_pos;
		}
	} elsif ($in_dir eq '-') {
		if (@Psh::Support::Dirs::stack>1) {
			if ($Psh::Support::Dirs::stack_pos==0) {
				$in_dir=$Psh::Support::Dirs::stack[1];
				$Psh::Support::Dirs::stack_pos=1;
			} else {
				$in_dir=$Psh::Support::Dirs::stack[0];
				$Psh::Support::Dirs::stack_pos=0;
			}
		}
	} elsif ($in_dir=~ /^\%(\d+)$/) {
		my $tmp_pos=$1;
		if ($tmp_pos>$#Psh::Support::Dirs::stack) {
			# TODO: Error handling
		} else {
			$in_dir=$Psh::Support::Dirs::stack[$tmp_pos];
			$Psh::Support::Dirs::stack_pos=$tmp_pos;
		}
	} else {
		$explicit=1 unless $in_dir eq $Psh::Support::Dirs::stack[0];
		# Don't push the same value again
		$Psh::Support::Dirs::stack_pos=0;
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
				unshift @Psh::Support::Dirs::stack, $dir if $explicit;
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

1;

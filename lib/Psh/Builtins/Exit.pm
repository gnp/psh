package Psh::Builtins::Exit;

use File::Spec;

=item * C<exit>

Exit out of the shell.

=cut

#
# TODO: What if a string is passed in?
#

sub bi_exit
{
	my $result = shift;
	$result = 0 unless defined($result) && $result;

	if ($Psh::save_history && $Psh::readline_saves_history) {
		$Psh::term->WriteHistory($Psh::history_file);
	}
	
	my $file= File::Spec->catfile(Psh::OS::get_home_dir(),".${Psh::bin}_logout");
	if( -r $file) {
		process_file(abs_path($file));
	}

	Psh::OS::exit($result);
}

1;

package Psh::Support::Builtins;

my %builtins=();

# Returns a list of builtins
sub get_builtin_commands {
	return keys %builtins;
}

# Called during initialization
sub build_autoload_list {
	%builtins= ();

	foreach my $tmp (@INC) {
		my $tmpdir= File::Spec->catdir($tmp,'Psh','Builtins');
		if (-r $tmpdir) {
			my @files= Psh::OS::glob('*.pm',$tmpdir);
			foreach( @files) {
				s/\.pm$//;
				$_= lc($_);
				$builtins{$_}= 1;
			}
		}
	}
}

sub is_builtin {
	return 1 if $builtins{$_[0]};
	return 0;
}


1;

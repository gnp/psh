package Psh::Support::Builtins;

my %builtins=();
my %builtin_aliases= (
					  '.' => 'source',
					  'options' => 'option',
					 );

# Returns a list of builtins
sub get_builtin_commands {
	return sort keys %builtins;
}

# Called during initialization
sub build_autoload_list {
	%builtins= ();

	my $unshift='';
	foreach my $tmp (@INC) {
		my $tmpdir= Psh::OS::catdir($tmp,'Psh','Builtins');
		if (-r $tmpdir) {
			$unshift=$tmp;
			my @files= Psh::OS::glob('*.pm',$tmpdir,1);
			foreach( @files) {
				s/\.pm$//;
				$_= lc($_);
				$builtins{$_}= 1;
			}
		}
	}
	unshift @INC, $unshift if $unshift;
}

sub is_builtin {
	my $name= shift;
	$name= $builtin_aliases{$name} if $builtin_aliases{$name};
	return $name if $builtins{$name};
	return 0;
}


1;

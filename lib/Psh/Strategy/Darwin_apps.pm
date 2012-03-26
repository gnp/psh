package Psh::Strategy::Darwin_apps;


=item * C<darwin_apps>

This strategy will search for Mac OS X/Darwin .app bundles and
execute them using the system 'open' command'

=cut

require Psh::Strategy;

@Psh::Strategy::Darwin_apps::ISA=('Psh::Strategy');

sub consumes {
	return Psh::Strategy::CONSUME_TOKENS;
}

sub runs_before {
	return qw(eval);
}

sub _recursive_search {
	my $file= shift;
	my $dir= shift;
	my $lvl= shift;

	opendir( DIR, $dir) || return ();
	my @files= readdir(DIR);
	closedir( DIR);
	my @result= map { Psh::OS::catdir($dir,$_) }
	  grep { lc("$file.app") eq lc($_) } @files;
	return $result[0] if @result;
	if ($lvl<10) {
		foreach my $tmp (@files) {
			my $tmpdir= Psh::OS::catdir($dir,$tmp);
			next if ! -d $tmpdir || !Psh::OS::no_upwards($tmp);
			next if index($tmpdir,'.')>=0;
			push @result, _recursive_search($file, $tmpdir, $lvl+1);
		}
	}
	return $result[0] if @result;
}


sub applies {
	my $com= $_[2]->[0];
	if ($com !~ m/$Psh::which_regexp/) { return ''; }
	my $path=$ENV{APP_PATH}||'/Applications';
	my @path= split /:/, $path;
	my $executable;
	foreach (@path) {
		$executable= _recursive_search($com,$_,1);
		last if $executable;
	}
	return $executable if defined $executable;
	return '';
}

sub execute {
	my $executable= $_[3];
	my $tmp= CORE::system("/usr/bin/open $executable");
	$tmp= $tmp/256;
	return ($tmp==0, undef, undef, $tmp);
}

1;

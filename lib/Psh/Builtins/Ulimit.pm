package Psh::Builtins::Ulimit;

require Psh::Util;

my %map= (
		  c => 'RLIMIT_CORE',
		  d => 'RLIMIT_DATA',
		  f => 'RLIMIT_FSIZE',
		  l => 'RLIMIT_MEMLOCK',
		  m => 'RLIMIT_RSS',
		  n => 'RLIMIT_NOFILE',
		  u => 'RLIMIT_NPROC',
		  s => 'RLIMIT_STACK',
		  t => 'RLIMIT_CPU',
          v => 'RLIMIT_AS',
		 );
my %desc=(
		  RLIMIT_CORE => 'maximum size of core files',
		  RLIMIT_DATA => 'maximum size of data segment',
		  RLIMIT_FSIZE => 'maximum file size',
		  RLIMIT_MEMLOCK => 'maximum size of locked memory',
		  RLIMIT_RSS => 'maximum resident size',
		  RLIMIT_NOFILE => 'maximum number of open files',
		  RLIMIT_NPROC => 'maximum number of user processes',
		  RLIMIT_STACK => 'maximum stack size',
		  RLIMIT_CPU => 'maximum cpu time',
		  RLIMIT_AS => 'size of virtual memory',
		 );

sub bi_ulimit {
	my $arg= shift;
	local @ARGV = @{shift()};

	eval {
		require BSD::Resource;
	};
	if ($@) {
		Psh::Util::print_error_i18n('bi_bsdresource');
		return undef;
	}
	eval {
		require Getopt::Std;
	};
	my $limits= BSD::Resource::get_rlimits();

	push @ARGV,'-c' unless @ARGV;

	my $type='S';
	my $opts= join('', keys %map,'SHa');
	my %opts=();
	Getopt::Std::getopts($opts,\%opts);

	if ($opts{'H'}) {
		$type='H';
	}
	if ($opts{'a'}) {
		foreach (keys %$limits) {
			my ($soft, $hard)= BSD::Resource::getrlimit($limits->{$_});
			my $val= $soft;
			$val= $hard if $type eq 'H';
			$val= 'unlimited' if $val<0;
			next unless $desc{$_};
			Psh::Util::print_out(sprintf("%-50s %s\n",$desc{$_},$val));
		}
	}
	return undef;
}

1;

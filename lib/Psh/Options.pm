package Psh::Options;

require Psh;
require Psh::OS;

# externally stored options
my %env_options= qw( cdpath 1 fignore 1 histsize 1 ignoreeof 1
                     ps1 1 ps2 1 path 1);

# internally stored options and their defaults
my %options=(
			 'array_exports' => {
								 'path' => $Psh::OS::PATH_SEPARATOR,
								 'classpath' => $Psh::OS::PATH_SEPARATOR,
								 'ld_library_path' => $Psh::OS::PATH_SEPARATOR,
								 'fignore' => $Psh::OS::PATH_SEPARATOR,
								 'cdpath' => $Psh::OS::PATH_SEPARATOR,
								 'ls_colors' => ':',
								},
			 'expansion' => 1,
			 'globbing'  => 1,
			 'window_title' => '\w',
			 'save_history' => 1,
			);

# setup defaults for ENV variables
if (!exists $ENV{HISTSIZE}) {
	$ENV{HISTSIZE}=50;
}

sub set_option {
	my $option= lc(shift());
	my @value= @_;
	my $val;
	if ($env_options{$option}) {
		if (@value>1 or (ref $value[0] and ref $value[0] eq 'ARRAY')) {
			if (ref $value[0]) {
				@value= @$value[0];
			}
			if ($options{array_exports}{$option}) {
				$val= join($options{array_exports}{$option},@value);
			} else {
				$val= $value[0];
			}
		} else {
			$val= $value[0];
		}
		$ENV{uc($option)}= $val;
	} else {
		if (@value>1) {
			$val= \@value;
		} else {
			$val= $value[0];
		}
		$options{$option}= $val;
	}
}

sub get_option {
	my $option= lc(shift());
	my $val;
	if ($env_options{$option}) {
		$val= $ENV{uc($option)};
		if ($options{array_exports}{$option}) {
			$val= [split($options{array_exports}{$option}, $val)];
		}
	} else {
		$val=$options{$option};
	}
	if (defined $val) {
		if (wantarray()) {
			if (ref $val and ref $val eq 'ARRAY') {
				return @{$val};
			} elsif ( ref $val and ref $val eq 'HASH') {
				return %{$val};
			}
			return $val;
		} else {
			return $val;
		}
	}
	return undef;
}

sub has_option {
	my $option= lc(shift());
	return 1 if exists $options{$option} or ($env_options{$option} and
											 exists $ENV{uc($option)});
	return 0;
}

sub del_option {
	my $option= lc(shift());
	if ($env_options{$option}) {
		delete $ENV{uc($option)};
	} else {
		delete $options{$option};
	}
}

sub list_options {
	my @opts= keys %options;
	foreach (keys %env_options) {
		push @opts, lc($_) if exists $ENV{uc($_)};
	}
	return @opts;
}

1;

package Psh::Builtins::Theme;

require File::Spec;
require Psh::Util;
require Psh::Parser;

=item * C<theme list>

Displays a list of available themes.

=item * C<theme NAME>

Activates the theme.

=cut

sub _parse_error {
	my $file= shift;
	Psh::Util::print_error("Error parsing themefile $file.\n");
	return (0,undef);
}

sub _set_theme {
	my $file= shift;
	if ($file=~/\.bt$/) {

	} else {
		open(THEME,"< $file");
		my @lines= <THEME>;
		close(THEME);
		if (!@lines) {
			Psh::Util::print_error("Could not find theme '$file'.\n");
			return (0,undef);
		}
		if ($lines[0]=~/^\#\!.*psh/) { # psh-script
			Psh::process_variable(join("\n",@lines));
			return (1,undef);
		} else { # try to parse it as a simple bashish theme
			my (@ps,$title);
			my $bashish_compat=0;
			foreach my $line (@lines) {
				next if substr($line,0,1) eq '#';
				if ($line=~/^\s*needmod\s+themecompat\s*$/) {
                    $bashish_compat=1;
				} elsif ($line=~/^\s*PS(\d)\s*\=\s*(.*)$/) {
					my ($num,$text)= ($1,$2);
					if ($num>0 and $num<5) {
						$ps[$num]= Psh::Parser::unquote($text);
					} else {
						return _parse_error($file);
					}
				} elsif ($line=~/^\s*PROMPT\s*\=\s*(.*)$/) {
					$ps[1]= Psh::Parser::unquote($1);
				} elsif ($line=~/^\s*TITLE\s*\=\s*(.*)$/) {
					$title= Psh::Parser::unquote($1);
				} elsif ($line=~/^\s*X.*COLOR.*\=/ or
						 $line=~/^\s*needmod\s+color/ or
						 $line=~/^\s*THEME_.*\=/ or
						 $line=~/^\s*SUPERPROMPT/ or
						 $line=~/^\s*CURCOLOR/ or
						 $line=~/^\s*$/) {
					# ignore
				} else {
					return _parse_error($file);
				}
			}
			if ($bashish_compat) {
				for (my $i=1; $i<=4; $i++) {
					next unless defined $ps[$i];
					$ps[$i]=~s/\$n/\\n/g; $ps[$i]=~s/\$t/\\t/g;
					$ps[$i]=~s/\$w/\\w/g; $ps[$i]=~s/\$W/\\W/g;
					$ps[$i]=~s/\$u/\\u/g; $ps[$i]=~s/\$c/\\!/g;
					$ps[$i]=~s/\$b/\\\$/g; $ps[$i]=~s/\$s/\\s/g;
					$ps[$i]=~s/\$h/\\h/g; $ps[$i]=~s/\$i/\\#/g;
					$ps[$i]=~s/\$d/\\d/g; $ps[$i]=~s/\$x/%/g;
					$ps[$i]=~s/\$e/\!/g;  $ps[$i]=~s/\$m/\$/g;
					$ps[$i]=~s/\$z/\\\$/g;
				}
			}
			Psh::Options::set_option('window_title',$title) if defined $title;
			for (my $i=1; $i<=4; $i++) {
				next unless defined $ps[$i];
				Psh::Options::set_option("ps$i",$ps[$i]);
			}
			return (1,undef);
		}
	}
}

sub bi_theme {
	my $line= shift;
	my @dirs= (File::Spec->catdir(File::Spec->rootdir,'usr','share',
								  'psh','themes'),
			   File::Spec->catdir(File::Spec->rootdir,'usr','local','share',
								  'psh','themes'),
			   File::Spec->catdir(Psh::OS::get_home_dir(),'.psh','themes'),
			   File::Spec->catdir(File::Spec->rootdir,'psh'));
	if ($line eq 'list') {
		my @result=();
		foreach my $dir (@dirs) {
			next unless -r $dir;
			my @tmp= Psh::OS::glob('*',$dir);
			foreach my $file (@tmp) {
				my $full= File::Spec->catfile($dir,$file);
				next if !-r $full or -d _;
				next if $file =~ /\~$/;
				$file=~ s/\.bt$//;
				push @result, $file;
			}
		}
		@result= sort @result;
		Psh::Util::print_list(@result);
		return (1,undef);
	} else {
		if ($line) {
			if ($line=~/$Psh::OS::FILE_SEPARATOR/) { # abs path specified
				my $tmp= Psh::Util::abs_path($line);
				return _set_theme($tmp) if $tmp;
			} else {
				foreach my $dir (@dirs) {
					next unless -r $dir;
					my $file= File::Spec->catfile($dir,$line);
					if (-r "$file.bt") {
						return _set_theme("$file.bt");
					} elsif (-r $file) {
						return _set_theme($file);
					}
				}
			}
			Psh::Util::print_error("Could not find theme '$line'.\n");
		}
	}
	return (0,undef);
}

1;

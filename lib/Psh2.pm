package Psh2;

use strict;

require POSIX;
require Psh2::Parser;

if ($^O eq 'MSWin32') {
    require Psh2::Windows;
} else {
    require Psh2::Unix;
}

build_builtin_list();

sub AUTOLOAD {
    no strict;
    $AUTOLOAD=~ s/.*:://g;
    my $ospackage= $^O eq 'MSWin32'?'Psh2::Windows':'Psh2::Unix';
    my $name= "${ospackage}::$AUTOLOAD";
    unless (ref *{$name}{CODE} eq 'CODE') {
	require Carp;
	Carp::croak("Function `$AUTOLOAD' does not exist.");
    }
    *$AUTOLOAD= *$name;
    goto &$AUTOLOAD;
}

sub DESTROY {}

sub new {
    my ($class)= @_;
    my $self= {
	       option =>
	       {
		array_exports =>
		{
		 path => path_separator(),
		 classpath => path_separator(),
		 ld_library_path => path_separator(),
		 fignore => path_separator(),
		 cdpath => path_separator(),
		 ld_colors => ':'
	     },
		frontend => 'readline',
	    },
	       strategy => [],
	       language => { 'perl' => 1, 'c' => 1},
	       tmp => {},
	       dirstack => [],
	       dirstack_pos => 0,
	   };
    bless $self, $class;
    return $self;
}

sub _eval {
    my $self= shift;
    my $lines= shift;
    while (my $element= shift @$lines) {
	my $type= shift @$element;
	if ($type == Psh2::Parser::T_EXECUTE()) {
	    $self->start_job($element);
	}
	elsif ($type == Psh2::Parser::T_OR()) {
	}
	elsif ($type == Psh2::Parser::T_AND()) {
	}
	else {
	    # TODO: Error handling
	}
    }
}

sub process {
    my ($self, $getter)= @_;

    while (1) {
	my $input= &$getter();

	unless (defined $input) {
	    last;
	}
	$self->reap_children();

	my $tmp= eval { Psh2::Parser::parse_line($input, $self); };
	# Todo: Error handling
	print STDERR $@ if $@;

	if ($tmp and @$tmp) {
	    _eval($self, $tmp);
	}
    }
}

sub process_file {
    my ($self, $file)= @_;
    local (*FILE);
    open( FILE, "< $file");
    $self->process( sub { my $txt=<FILE>; $txt});
    close( FILE);
}

sub process_args {
    my $self= shift;
    foreach my $arg (@_) {
	if (-r $arg) {
	    $self->process_file($arg);
	}
    }
}

sub process_variable {
    my $self= shift;
    my $var= shift;
    local $self->{interactive}= 0;
    my @lines;
    if (ref $var eq 'ARRAY') {
	@lines= @$var;
    } else {
	@lines= split /\n/, $var;
    }
    $self->process(sub { shift @lines });
}

sub process_rc {
}

sub main_loop {
    my $self= shift;

    $self->{interactive}= (-t STDIN) and (-t STDOUT);

    my $getter;
    if ($self->{interactive}) {
	$getter= sub { $self->fe->getline(@_) };
    } else {
	$getter= sub { return <STDIN>; };
    }
    $self->process($getter);
}

sub init_minimal {
    my $self= shift;
    $| = 1;
    setup_signal_handlers();
}

sub init_finish {
    my $self= shift;
    if ($self->{option}{locale}) {
	require Locale::gettext;
	Locale::gettext::textdomain('psh2');
	*gt= *gt_locale;
    } else {
	*gt= *gt_dummy;
    }
}

sub init_interactive {
    my $self= shift;
    my $frontend_name= 'Psh2::Frontend::'.ucfirst($self->{option}{frontend});
    eval "require $frontend_name";
    if ($@) {
	print STDERR $@;
	# TODO: Error handling
    }
    $self->{frontend}= $frontend_name->new($self);
    $self->fe->init();
    setup_signal_handlers();
}

############################################################################
##
## Input/Output
##
############################################################################

sub gt_dummy {
    if (@_ and ref $_[0]) {
	shift @_;
    }
    return $_[0];
}

sub gt_locale {
    if (@_ and ref $_[0]) {
	shift @_;
    }
    return Locale::gettext($_[0]);
}

sub print {
    my $self= shift;
    if ($self->fe) {
	$self->fe->print(0, @_);
    } else {
	CORE::print STDOUT @_;
    }
}

sub printerr {
    my $self= shift;
    if ($self->fe) {
	$self->fe->print(1, @_);
    } else {
	CORE::print STDERR @_;
    }
}

sub printdebug {
    my $self= shift;
    my $debugclass= shift;
    return if !$self->{option}{debug} or
	($self->{option}{debug} ne '1' and
	 $self->{option}{debug} !~ /\Q$debugclass\E/);

    if ($self->fe) {
	$self->fe->print(2, @_);
    } else {
	CORE::print STDERR @_;
    }
}

############################################################################
##
## Filehandling
##
############################################################################

{
    my %path_hash=();

    sub abs_path {
	my $self= shift;
	my $path= shift;
	return undef unless $path;
	return $path_hash{$path} if $path_hash{$path};
	my $result;
	if ($^O eq 'MSWin32' and defined &Win32::GetFullPathName) {
	    $result= Win32::GetFullPathName($path);
	    $result=~ tr:\\:/:;
	} else {
	    if ($path eq '~') {
	    }
	    elsif ( substr($path, 0, 2) eq '~/') {
	    }
	    elsif ( substr($path, 0, 1) eq '~') {
	    }
	    unless ($result) {
		my $tmp= rel2abs( $self, $path, $ENV{PWD});
		my $old= $ENV{PWD};
		if ($tmp and -r $tmp) {
		    if (-d $tmp and -x _) {
			if (CORE::chdir($tmp)) {
			    $result= getcwd();
			    if (!CORE::chdir($old)) {
				# TODO: Error handling
			    }
			}
		    } else {
			$result= $tmp;
		    }
		}
		return undef unless $result;
	    }
	}
	if ($result) {
	    $result.='/' unless $result =~ m:[/\\]:;
	}
	$path_hash{$path}= $result if file_name_is_absolute($self, $path);
	return $result;
    }


    my $tmp= quotemeta(file_separator());
    my $re= qr/^(.*)$tmp([^$tmp]+)$/;
    my %command_hash= ();
    my $last_path_cwd;
    my @absed_path;

    sub which {
	my ($self, $command, $all_flag)= @_;
	return undef unless $command;

	if (index($command, file_separator())>-1) {
	    $command=~ $re;
	    my $path_element= $1 || '';
	    my $cmd_element = $2 || '';
	    return undef unless $path_element and $cmd_element;
	    $path_element= abs_path($self, $path_element);
	    my $try= catfile($path_element, $cmd_element);
	    if (-x $try and ! -d _ ) {
		return $try;
	    }
	    return undef;
	}
	return $command_hash{$command} if exists $command_hash{$command}
	  and !$all_flag;

	return undef if $command !~ /^[-a-zA-Z0-9_.~+]+$/;

	if (!@absed_path or $last_path_cwd ne ($ENV{PATH}.$ENV{PWD})) {
	    $last_path_cwd= $ENV{PATH}.$ENV{PWD};
	    _recalc_absed_path($self);
	}
	my $path_ext= get_path_extension();
	my @all= ();
	foreach my $dir (@absed_path) {
	    next unless $dir;
	    my $try= catfile($self, $dir, $command);
	    foreach my $ext (@$path_ext) {
		my $tmp= $try.$ext;
		if (-x $tmp and !-d _) {
		    $command_hash{$command}= $tmp;
		    return $tmp unless $all_flag;
		    push @all, $tmp;
		}
	    }
	}
	if ($all_flag and @all) {
	    return @all;
	}
	$command_hash{$command}= undef; # speeds up locating non-commands
	return undef;
    }

    sub _recalc_absed_path {
	my $self= shift;

	@absed_path= ();
	%command_hash= ();
	my @path= split path_separator(), $ENV{PATH};
	eval {
	    foreach my $dir (@path) {
		next unless $dir;
		$dir= abs_path($self, $dir);
		next unless $dir and -r $dir and -x _;
		push @absed_path, $dir;
	    }
	};
	# TODO: Error handling
    }
}

#
# The following code is here because it is most probably
# portable across at least a large number of platforms
# If you need to override them, then modify the symbol
# table :-)

# recursive glob function used for **/anything glob
sub _recursive_glob {
    my( $pattern, $dir)= @_;
    opendir( DIR, $dir) || return ();
    my @files= readdir(DIR);
    closedir( DIR);
    my @result= map { catdir(undef, $dir,$_) }
      grep { /^$pattern$/ } @files;
    foreach my $tmp (@files) {
	my $tmpdir= catdir(undef, $dir,$tmp);
	next if ! -d $tmpdir || !no_upwards($tmp);
	push @result, _recursive_glob($pattern, $tmpdir);
    }
    return @result;
}

sub _escape {
    my $text= shift;
    $text=~s/(?<!\\)([^a-zA-Z0-9\*\?])/\\$1/g;
    return $text;
}

#
# The Perl builtin glob STILL uses csh, furthermore it is
# not possible to supply a base directory... so I guess this
# is faster
#
sub glob {
    my( $self, $pattern, $dir, $already_absed) = @_;

    return () unless $pattern;

    my @result;
    if( !$dir) {
	$dir=$ENV{PWD};
    } else {
	$dir=abs_path($self, $dir) unless $already_absed;
    }
    return unless $dir;

    # Expand ~
    my $home= $ENV{HOME}; #||get_home_dir();
    if ($pattern eq '~') {
	$pattern=$home;
    } else {
	$pattern=~ s|^\~/|$home/|;
	$pattern=~ s|^\~([^/]+)|&get_home_dir($1)|e;
    }
    
    return $pattern if $pattern !~ /[*?]/;
    
    # Special recursion handling for **/anything globs
    if( $pattern=~ m:^([^\*]+/)?\*\*/(.*)$: ) {
	my $tlen= length($dir)+1;
	my $prefix= $1||'';
	$pattern= $2;
	$prefix=~ s:/$::;
	$dir= catdir($self, $dir,$prefix);
	$pattern=_escape($pattern);
	$pattern=~s/\*/[^\/]*/g;
	$pattern=~s/\?/./g;
	$pattern='[^\.]'.$pattern if( substr($pattern,0,2) eq '.*');
	@result= map { substr($_,$tlen) } _recursive_glob($pattern,$dir);
    } elsif( $pattern=~ m:/:) {
	# Too difficult to simulate, so use slow variant
	my $old=$ENV{PWD};
	CORE::chdir $dir;
	$pattern=_escape($pattern);
	@result= eval { CORE::glob($pattern); };
	CORE::chdir $old;
    } else {
	# The fast variant for simple matches
	$pattern=_escape($pattern);
	$pattern=~s/\*/.*/g;
	$pattern=~s/\?/./g;
	$pattern='[^\.]'.$pattern if( substr($pattern,0,2) eq '.*');
	
	opendir( DIR, $dir) || return ();
	@result= grep { /^$pattern$/ } readdir(DIR);
	closedir( DIR);
    }
    return @result;
}

############################################################################
##
## Misc. Accessors
##
############################################################################

sub fe {
    return shift()->{frontend};
}


############################################################################
##
## Options System
##
############################################################################

my %env_option= qw( cdpath 1 fignore 1 histsize 1 ignoreeof 1 ps1 1
		     psh2 1 path 1);

sub set_option {
    my $self= shift;
    my $option= lc(shift());
    my @value= @_;
    return unless $option;
    return unless @value;
    my $val;
    if ($env_option{$option}) {
	if (@value>1 or (ref $value[0] and ref $value[0] eq 'ARRAY')) {
	    if (ref $value[0]) {
		@value= @{$value[0]};
	    }
	    if ($self->{option}{array_exports} and
		$self->{option}{array_exports}{$option}) {
		$val= join($self->{option}{array_exports}{$option},@value);
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
	$self->{option}{$option}= $val;
    }
}

sub get_option {
    my $self= shift;
    my $option= lc(shift());
    my $val;
    if ($env_option{$option}) {
	$val= $ENV{uc($option)};
	if ($self->{option}{array_exports} and
	    $self->{option}{array_exports}{$option}) {
	    $val= [split($self->{option}{array_exports}{$option}, $val)];
	}
    } else {
	$val=$self->{option}{$option};
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
    my $self= shift;
    my $option= lc(shift());
    return 1 if exists $self->{option}{$option} or
	($env_option{$option} and $ENV{uc($option)});
    return 0;
}

sub del_option {
    my $self= shift;
    my $option= lc(shift());
    if ($env_option{$option}) {
	delete $ENV{uc($option)};
    } else {
	delete $self->{option}{$option};
    }
}

sub list_option {
    my $self= shift;
    my @opts= keys %{$self->{option}};
    foreach (keys %env_option) {
	push @opts, lc($_) if exists $ENV{uc($_)};
    }
    return @opts;
}


############################################################################
##
## Built-Ins
##
############################################################################

{
    my %builtin;
    my %builtin_aliases= (
			  '.' => 'source',
			  'options' => 'option',
			 );
    sub is_builtin {
	my ($self, $com)= @_;
	$com= $builtin_aliases{$com} if $builtin_aliases{$com};
	return 1 if exists $builtin{$com};
	return 0;
    }

    sub build_builtin_list {
	%builtin= ();
	my $unshift= '';
	foreach my $tmp (@INC) {
	    my $tmpdir= catdir( undef, $tmp, 'Psh2', 'Builtins');
	    if (-r $tmpdir) {
		my @files= Psh2->glob('*.pm', $tmpdir, 1);
		foreach (@files) {
		    s/\.pm$//;
		    $_= lc($_);
		    $builtin{$_}= 1;
		}
	    }
	}
    }
}

############################################################################
##
## Jobs
##
############################################################################

{
    my @order= ();
    my %list= ();
    my $current_job=0;

    sub start_job {
	my $self= shift;
	my $array= shift;
	my $fgflag= shift @$array;

	my $visline= '';
	my ($read, $chainout, $chainin, $pgrp_leader);
	my $tmplen= @$array- 1;
	my @pids= ();
	my $success;
	for (my $i=0; $i<@$array; $i++) {
	    # [ $strategy, $how, $options, $words, $line, $opt ]
	    my ($strategy, $how, $options, $words, $text, $opt)= @{$array->[$i]};

	    my $fork= 0;
	    if ($i<$tmplen or !$fgflag or
		($strategy ne 'builtin' and
		 ($strategy ne 'language' or !$how->internal()))) {
		$fork= 1;
	    }

	    if ($tmplen) {
		($read, $chainout)= POSIX::pipe();
	    }
	    foreach (@$options) {
		if ($_->[0] == Psh2::Parser::T_REDIRECT() and
		    ($_->[1] eq '<&' or $_->[1] eq '>&')) {
		    if ($_->[3] eq 'chainin') {
			$_->[3]= $chainin;
		    } elsif ($_->[3] eq 'chainout') {
			$_->[3]= $chainout;
		    }
		}
	    }
	    my $termflag= !($i==$tmplen);
	    my $pid= 0;
	    if ($^O eq 'MSWin32') {
	    } else {
		if ($fork) {
		    ($pid)= $self->fork($array->[$i], $pgrp_leader, $fgflag,
					$termflag);
		} else {
		    ($success)= $self->execute($array->[$i]);
		}
	    }
	    if (!$i and !$pgrp_leader and $pid) {
		$pgrp_leader= $pid;
	    }
	    if ($i<$tmplen and $tmplen) {
		POSIX::close($chainout);
		$chainin= $read;
	    }
	    $visline.='|' if $i>0;
	    $visline.= $text;
	    push @pids, $pid if $pid;
	}
	if (@pids) {
	    my $job;
	    if ($^O eq 'MSWin32') {
	    } else {
		$job= Psh2::Unix::Job->new( pgrp_leader => $pgrp_leader,
					    pids => \@pids,
					    desc => $visline,
					    psh  => $self,);
		foreach (@pids) {
		    $list{$_}= $job;
		}
		push @order, $job;
		$current_job= $#order;
		if ($fgflag) {
		    $success= $job->wait_for_finish(1);
		} else {
		    my $visindex= @order;
		    my $verb= $self->gt('background');
		    $self->print("[$visindex] \u$verb $pgrp_leader $visline\n");
		}
	    }
	}
	return $success;
    }

    sub delete_job {
	my $self= shift;
	my ($pid) = @_;

	my $job= $list{$pid};
	return unless defined $job;

	delete $list{$pid};
	my $i;
	for ($i=0; $i <= $#order; $i++) {
	    last if( $order[$i]==$job);
	}

	splice( @order, $i, 1);
    }

    sub get_current_job {
	return $order[$current_job];
    }

    sub set_current_job {
	my $self= shift;
	$current_job= shift();
    }

    sub job_exists {
	my $self= shift;
	my $pid= shift;
	return exists $list{$pid};
    }

    sub get_job {
	my $self= shift;
	my $pid= shift;
	return $list{$pid};
    }

    sub list_jobs {
	return wantarray?@order:\@order;
    }

    sub find_job {
	my $self= shift;
	my $job_to_start= shift;

	return $order[$job_to_start] if defined( $job_to_start);

	for (my $i = $#order; $i >= 0; $i--) {
	    my $job = $order[$i];
	    if (!$job->{running}) {
		return $job;
	    }
	}
	return undef;
    }


    sub find_last_with_name {
	my ($self, $name, $runningflag) = @_;
	my $i= $#order;
	while (--$i) {
	    my $job= $order[$i];
	    next if $runningflag and $job->{running};
	    my $desc= $job->{desc};
	    if ($desc=~ m:([^/\s]+)\s*: ) {
		$desc= $1;
	    } elsif ( $desc=~ m:/([^/\s]+)\s+.*$: ) {
		$desc= $1;
	    } elsif ( $desc=~ m:^([^/\s]+): ) {
		$desc= $1;
	    }
	    if ($desc eq $name) {
		return $job;
	    }
	}
	return undef;
    }

    sub get_job_number {
	my ($self, $pid)= @_;

	for ( my $i=0; $i<=$#order; $i++) {
	    return $i+1 if( $order[$i]->{pgrp_leader}==$pid);
	}
	return -1;
    }
}

1;

package Psh2;

use strict;
require Psh2::Parser;
use Data::Dumper;

if ($^O eq 'MSWin32') {
    require Psh2::Windows;
} else {
    require Psh2::Unix;
}

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
	       language => {},
	       tmp => {},
	   };
    bless $self, $class;
    return $self;
}

sub process {
    my ($self, $getter)= @_;

    while (1) {
	my $input= &$getter();

	unless (defined $input) {
	    last;
	}
	my $tmp= eval { Psh2::Parser::parse_line($input, $self); };
	print $@ if $@;
	print Dumper($tmp) if $tmp;

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
		my $tmp= rel2abs( $path, $ENV{PWD});
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
	$path_hash{$path}= $result if file_name_is_absolute($path);
	return $result;
    }


    my $tmp= quotemeta(file_separator());
    my $re1= qr/$tmp/;
    my $re2= qr/^(.*)$tmp([^$tmp]+)$/;
    my %command_hash= ();
    my $last_path_cwd;
    my @absed_path;

    sub which {
	my ($self, $command, $all_flag)= @_;
	return undef unless $command;

	if ($command =~ $re1) {
	    $command=~ $re2;
	    my $path_element= $1 || '';
	    my $cmd_element = $2 || '';
	    return undef unless $path_element and $cmd_element;
	    $path_element= abs_path($path_element);
	    my $try= catfile($path_element, $cmd_element);
	    if (-x $try and ! -d _ ) {
		return $try;
	    }
	    return undef;
	}
	return $command_hash{$command} if exists $command_hash{$command}
	  and !$all_flag;

	return undef if $command !~ /^[-a-zA-Z0-9_.~+]$/;

	if (!@absed_path or $last_path_cwd ne ($ENV{PATH}.$ENV{PWD})) {
	    $last_path_cwd= $ENV{PATH}.$ENV{PWD};
	    _recalc_absed_path();
	}
	return undef;
    }

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

sub is_builtin {
    return 0;
}

1;

package Psh::Completion;

use strict;
use vars qw($ac $complete_first_word_dirs);

require Psh::Util;
require Psh::OS;

my $APPEND="not_implemented";

@Psh::Completion::bookmarks= ();
@Psh::Completion::autoload=();

sub init
{
	my $attribs=$Psh::term->Attribs;

	# The following is ridiculous, but....
	if( $Psh::term->ReadLine eq 'Term::ReadLine::Perl') {
		$APPEND='completer_terminator_character';
	} elsif( $Psh::term->ReadLine eq 'Term::ReadLine::Gnu') {
		$APPEND='completion_append_character';
	}

	# Only ::Gnu understand it, and ::Perl ignores it silently.
	$attribs->{completion_display_matches_hook}
	    = \&display_match_list;
}

{
	my $kh_loaded=0;
	sub bookmarks {
		return @Psh::Completion::bookmarks if $kh_loaded;
		push @Psh::Completion::bookmarks, Psh::OS::get_known_hosts();
		$kh_loaded=1;
		return @Psh::Completion::bookmarks;
	}
}

# Returns a list of possible file completions
sub cmpl_filenames
{
	my $text= shift;
	my $executable_only= shift||0;

	my $exclam=0;

	if ( $executable_only) {
		if ($text=~s/^\!//) {
			$exclam=1;
		}
	}

	my $globtext= $text;
	my $prepend= '';

	if( substr($text,0,1) eq '"') {
		$prepend='"';
		$globtext= substr($text,1);
	}

	my @result;

	if (substr($globtext,0,1) eq '~' and !($globtext=~/\//)) {
		# after ~ try username completion
		@result= cmpl_usernames($globtext);
		$ac="/" if @result;
		return @result;
	}

	@result= Psh::OS::glob("$globtext*");

	if( Psh::Options::has_option('fignore')) {
		my @ignore= Psh::Options::get_option('fignore');
		@result= grep {
			my $item= $_;
			my $result= ! grep { Psh::Util::ends_with($item,$_) } @ignore;
			$result;
		} @result;
	}

	if ( $executable_only) {
		@result= grep { -x $_ || -d $_ } @result;
	}

	@result= map { -d $_ ? "$_/" : $_ } @result;

	# HACK: This won't help much if user tries to do another completion
	# on the same item afterwards
	@result= map { s/([ \'\"\´\`])/\\$1/g; $_ } @result unless $prepend eq '"';

	if(@result==1) {
		if (substr($result[0],-1) eq '/') {
			$ac='';
		}
		$ac=$prepend.$ac if $prepend;
	}

	foreach (@result) {
		if( m|/([^/]+\/?)$| ) {
			$_=$1;
		}
	}

	return @result;
}


# Returns a list of possible directory completions
sub cmpl_directories
{
	my $text= shift;
	my $globtext= $text;
	my $prepend= '';

	if( substr($text,0,1) eq '"') {
		$prepend='"';
		$globtext= substr($text,1);
	}

	my @result;
	if (substr($globtext,0,1) eq '~' and !($globtext=~/\//)) {
		# after ~ try username completion
		@result= cmpl_usernames($globtext);
		$ac="/" if @result;
		return @result;
	}

	@result= grep { -d $_ } Psh::OS::glob("$globtext*");

	$ac=$prepend||'';

	@result= map { $_.'/' } @result;

	foreach (@result) {
		if( m|/([^/]+/?)$| ) {
			$_=$1;
		}
	}

	return @result;
}


# Returns an array with possible username completions
sub cmpl_usernames
{
	my $text= shift;
	my @result= grep { Psh::Util::starts_with($_,$text) } Psh::OS::get_all_users();
	return @result;
}


#
# Tries to find executables for possible completions
sub cmpl_executable
{
	my $cmd= shift;
	my @result = ();
	my $exclam=0;

	if ($cmd=~s/^\!//) {
		$exclam=1;
	}

	if (Psh::Strategy::active('built_in')) {
		push @result, grep { Psh::Util::starts_with($_,$cmd) } Psh::Support::Alias::get_alias_commands();
		push @result, grep { Psh::Util::starts_with($_,$cmd) } Psh::Support::Builtins::get_builtin_commands();
	}
	push @result, cmpl_directories($cmd) if $complete_first_word_dirs;
	
	local $^W= 0;

	Psh::Util::which($cmd);
	# set up absed_path if not already set and check
	
	foreach my $dir (@Psh::absed_path) {
		push( @result, map { $exclam?'!'.$_:$_ }
			  grep { -x $dir.'/'.$_&& ! -d } Psh::OS::glob("$cmd*",$dir) );
	}
	return @result;
}


#
# Completes perl symbols
#
# TODO: Also complete package variables and package names
#	by managing $CWP in top command loop or by buildin `package' command.
#

# $CWP : Current Working Package (not implemented yet)
use vars qw($CWP);
BEGIN { $CWP = 'main' }

{
	my %type;

	BEGIN {
		%type = ('$' => 'SCALAR', '*' => 'SCALAR',
			 '@' => 'ARRAY', '$#' => 'ARRAY',
			 '%' => 'HASH',
			 '&' => 'CODE');
	}

	sub cmpl_symbol {
		my ($text, $line, $start) = @_;
	
		my ($prefix, $pre, $pkg, $sym);
			no strict qw(refs);
		($prefix, $pre, $pkg) = ($text =~ m/^((\$#|[\@\$%&])(.*::)?)/);
		my @packages = grep /::$/, $pkg ? keys %$pkg : keys %::;
		$pkg = ($CWP eq 'main' ? '::' : $CWP . '::') unless $pkg;
		
		my @symbols;
		if ($pre eq '$') {
			no strict 'vars'; # make `eval' quiet
			# I cannot use `defined *$sym{SCALAR}',
			# since it is always true.
			@symbols = grep (/^\w+$/
					 && (eval "defined $prefix$_"
					     || ($sym = $pkg . $_,
						 defined *$sym{ARRAY}
						 || defined *$sym{HASH})),
					     keys %$pkg);
			} else {
			@symbols = grep (/^\w+$/
					 && ($sym = $pkg . $_,
					     defined *$sym{$type{$pre}}),
					 keys %$pkg);
		}
		# Do we need a user customizable variable to ignore @packages?
		return grep(/^\Q$text/,
			    map($prefix . $_, @packages, @symbols));
	}
}

#
# Completes key names for Perl hashes
#
sub cmpl_hashkeys {
	my ($text, $line, $start) = @_;

	my $tmp= substr($line, 0, $start + 1);
	my ($var,$arrow) = ($tmp =~ m/^[\$\%]([\w:]+)\s*(->)?\s*\{\s*['"]?/);
	return () unless $var;

	no strict 'refs';
	$var = "${CWP}::$var" unless ($var =~ m/::/);
	return () unless $var;
	if ($arrow) {
		my $hashref = eval "\$$var";
		return grep(/^\Q$text/, keys %$hashref);
	} else {
		return grep(/^\Q$text/, keys %$var);
	}
}

sub _search_ISA {
	my ($mypkg) = @_;
		no strict qw(refs);
	my $isa = "${mypkg}::ISA";
	return $mypkg, map _search_ISA($_), @$isa;
}

sub cmpl_method {
	my ($text, $line, $start) = @_;
	
	my ($var, $pkg, $sym, $pk);
	$var = (substr($line, 0, $start + 1)
		=~ m/\$([\w:]+)\s*->\s*$/)[0];
	$pkg = ref eval (($var =~ m/::/) ? "\$$var" : "\$${CWP}::$var");
	no strict qw(refs);
	return grep(/^\Q$text/,
		    map { $pk = $_ . '::';
			  grep (/^\w+$/
				&& ($sym = "${pk}$_", defined *$sym{CODE}),
				keys %$pk);
		  } _search_ISA($pkg));
}

{
	my @keyword;

	# complete perl bare words (Perl function, subroutines, filehandle)
	sub cmpl_perl_function {
		my ($text) = @_;

		my ($prefix, $pkg, $sym);
		no strict qw(refs);
		($prefix, $pkg) = ($text =~ m/^((.*::)?)/);
		my @packages = grep /::$/, $pkg ? keys %$pkg : keys %::;
		$pkg = ($CWP eq 'main' ? '::' : $CWP . '::') unless $pkg;
		
		my @subs = grep (/^\w+$/
				 && ($sym = $pkg . $_,
				     defined *$sym{CODE}
				     || defined *$sym{FILEHANDLE}),
				 keys %$pkg);
		# Do we need a user customizable variable to ignore @packages?
		my @result= grep(/^\Q$text/,
						 !$prefix && @keyword,
						 map($prefix . $_, @packages, @subs));
		if (@result==1) {
			$ac='';
		}
		return @result;
    }

	BEGIN {
		# from perl5.004_02 perlfunc
		@keyword = qw(
		    chomp chop chr crypt hex index lc lcfirst
		    length oct ord pack q qq
		    reverse rindex sprintf substr tr uc ucfirst
		    y
		    
		    m pos quotemeta s split study qr

		    abs atan2 cos exp hex int log oct rand sin
		    sqrt srand

		    pop push shift splice unshift

		    grep join map qw reverse sort unpack
		    
		    delete each exists keys values
		    
		    binmode close closedir dbmclose dbmopen die
		    eof fileno flock format getc print printf
		    read readdir rewinddir seek seekdir select
		    syscall sysread sysseek syswrite tell telldir
		    truncate warn write
		    
		    pack read syscall sysread syswrite unpack vec
		    
		    chdir chmod chown chroot fcntl glob ioctl
		    link lstat mkdir open opendir readlink rename
		    rmdir stat symlink umask unlink utime
		    
		    caller continue die do dump eval exit goto
		    last next redo return sub wantarray
		    
		    caller import local my package use
		    
		    defined dump eval formline local my reset
		    scalar undef wantarray
		    
		    alarm exec fork getpgrp getppid getpriority
		    kill pipe qx setpgrp setpriority sleep
		    system times wait waitpid
		    
		    do import no package require use
		    
		    bless dbmclose dbmopen package ref tie tied
		    untie use
		    
		    accept bind connect getpeername getsockname
		    getsockopt listen recv send setsockopt shutdown
		    socket socketpair
		    
		    msgctl msgget msgrcv msgsnd semctl semget
		    semop shmctl shmget shmread shmwrite
		    
		    endgrent endhostent endnetent endpwent getgrent
		    getgrgid getgrnam getlogin getpwent getpwnam
		    getpwuid setgrent setpwent
		    
		    endprotoent endservent gethostbyaddr
		    gethostbyname gethostent getnetbyaddr
		    getnetbyname getnetent getprotobyname
		    getprotobynumber getprotoent getservbyname
		    getservbyport getservent sethostent setnetent
		    setprotoent setservent
		    
		    gmtime localtime time times
		    
		    abs bless chomp chr exists formline glob
		    import lc lcfirst map my no prototype qx qw
		    readline readpipe ref sub sysopen tie tied
		    uc ucfirst untie use
		    
		    dbmclose dbmopen
		   );
	}
}

#
# completion(text,line,start,end)
#
# Main Completion function
#

sub completion
{
	my ($text, $line, $start) = @_;
	my $attribs               = $Psh::term->Attribs;

	my @tmp=();

	my $startchar= substr($line, $start, 1);
	my $starttext= substr($line, 0, $start);
	$starttext =~ /^\s*(\S+)\s+/;
	my $command= $1 || '';

	my $pretext= '';
	if( $starttext =~ /\s(\S*)$/) {
		$pretext= $1;
	} elsif( $starttext =~ /^(\S*)$/) {
		$pretext= $1;
	}

	# are we in backticks or after a pipe ?
	if( $starttext =~ /.*[\|\`]\s*(\S+)\s+/) {
		$command= $1;
	}

	my $firstflag= $starttext !~/\s/;

	$ac=' ';

	if ($Psh::PCompletion::LOADED) {
		# Check completion-spec is defined or not.
		my $cmd;
		$command =~ m|^\s*(\S*/)?(\S*)|;
		my $dir=$1||'';
		my $base=$2||'';
		my $cs = $Psh::PCompletion::COMPSPEC{$cmd = $dir . $base}
		  || $Psh::PCompletion::COMPSPEC{$cmd = $base};
		my $universal=0;
		unless (defined $cs) {
			$cs= $Psh::PCompletion::COMPSPEC{'*'};
			$cmd= $dir.$base;
			$universal=1;
		}

		# Do programmable completion if completion-spec is defined.
		# This is done here to keep the compatibility with bash.
		if (defined $cs) {
			# remove prefix string if it is already prefixed.
			$text =~ s/^\Q$cs->{prefix}//
			  if (defined $cs->{prefix});
			@tmp = Psh::PCompletion::pcomp_list($cs, $text, $line, $start, $cmd);
			if (!@tmp) {
				if ($cs->{option} and $cs->{option} eq 'default') {
				} elsif ($universal) {
					# ignore both cases
				} else {
					return ();
				}
			} else {
				$attribs->{$APPEND}=$ac;
				return @tmp;
			}
		}
	}

	if ($starttext =~ m/\$([\w:]+)\s*(->)?\s*{\s*['"]?$/) {
		# $foo{key, $foo->{key
		@tmp= cmpl_hashkeys($text, $line, $start);
		$ac = '}';
	} elsif ($starttext =~ m/\$([\w:]+)\s*->\s*['"]?$/) {
		# $foo->method
		@tmp= cmpl_method($text, $line, $start);
		$ac = ' ';
	} elsif ( $text =~ /^\$#|[\@\$%&]/) {
		# $foo, @foo, $#foo, %foo, &foo
		@tmp= cmpl_symbol($text, $line, $start);
		$ac = '';
	} elsif( $firstflag || $starttext =~ /[\|\`]\s*$/) {
		# we have the first word in the line or a pipe sign/backtick in front
		# of the current item, so we try to complete executables
		
		if ($pretext=~m/\//) {
			@tmp = cmpl_filenames($pretext.$text,1)
		} else {
			@tmp= cmpl_executable($text);
		}
		unless ($pretext) {
			# Afterwards we add possible matches for perl barewords
			push @tmp, cmpl_perl_function($text);
		}
	} else {
		@tmp = cmpl_filenames($pretext.$text);
	}

	if (Psh::Strategy::active('built_in') and
		grep { $_ eq $command } Psh::Support::Builtins::get_builtin_commands() ) {
		my $pkg= ucfirst($command);
		eval "require Psh::Builtins::$pkg";
		Psh::Util::print_debug_class('e',"Error: $@") if $@;
		my @tmp2= eval 'Psh::Builtins::'.$pkg.'::cmpl_'."$command('$text','$pretext','$starttext','$line')";
		if( @tmp2 && $tmp2[0]) {
			shift(@tmp2);
			@tmp= @tmp2;
		} else {
			shift(@tmp2);
			push @tmp, @tmp2;
		}
	}

	$attribs->{$APPEND}=$ac;
	return @tmp;
}

sub display_match_list {
    my($matches, $num_matches, $max_length) = @_;
	shift @$matches;

    map { $_ =~ s/^((\$#|[\@\$%&])?).*::(.+)/$3/; }(@{$matches});
	#map { $_ =~ s/^([^\/]+)\/$/\001\e[01;34m\002$1\001\e[00m\002\//; } (@{$matches});
    $Psh::term->display_match_list($matches);
	#print STDOUT "\n";
	#Psh::Util::print_list($matches,$max_length);
    eval {
		$Psh::term->forced_update_display if defined $Psh::term;
	};
}

1;
__END__

=head1 NAME

Psh::Completion - containing the completion routines of psh.
Currently works with Term::ReadLine::Gnu and Term::ReadLine::Perl.

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 AUTHOR

Markus Peter, warp@spin.de
Hiroo Hayashi, hiroo.hayashi@computer.org

=head1 SEE ALSO


=cut

package Psh::Strategy::Perlfunc_heavy;

=item * C<perlfuncheavy>

Tries to detect perl builtins - this is helpful if you e.g. have
a print command on your system.

=cut

require Psh::Strategy;

use vars qw($builtins $packages $expand_arguments @ISA);

$builtins=0;
$packages=1;

@ISA=('Psh::Strategy');


sub new { Psh::Strategy::new(@_) }

sub consumes {
	return Psh::Strategy::CONSUME_TOKENS;
}

sub runs_before {
	return qw(perlscript auto_resume executable);
}

#
# TODO: Is there a better way to detect Perl built-in-functions and
# keywords than the following? Surprisingly enough,
# defined(&CORE::abs) does not work, i.e., it returns false.
#
# If a value is anything > 1, then it's the minimum number of
# arguments for that function
#

my %perl_builtins = qw( -X 1 abs 1 accept 1 alarm 1 atan2 1 bind 1
binmode 1 bless 1 caller 1 chdir 1 chmod 3 chomp 1 chop 1 chown 3 chr
1 chroot 1 close 1 closedir 1 connect 3 continue 1 cos 1 crypt 1
dbmclose 1 dbmopen 1 defined 1 delete 1 die 1 do 1 dump 1 each 1
endgrent 1 endhostent 1 endnetent 1 endprotoent 1 endpwent 1
endservent 1 eof 1 eval 1 exec 3 exists 1 exit 1 exp 1 fcntl 1 fileno
1 flock 1 for 1 foreach 1 fork 1 format 1 formline 1 getc 1 getgrent 1
getgrgid 1 getgrnam 1 gethostbyaddr 1 gethostbyname 1 gethostent 1
getlogin 1 getnetbyaddr 1 getnetbyname 1 getnetent 1 getpeername 1
getpgrp 1 getppid 1 getpriority 1 getprotobyname 1 getprotobynumber 1
getprotoent 1 getpwent 1 getpwnam 1 getpwuid 1 getservbyname 1
getservbyport 1 getservent 1 getsockname 1 getsockopt 1 glob 1 gmtime
1 goto 1 grep 3 hex 1 import 1 if 1 int 1 ioctl 1 join 1 keys 1 kill 1
last 1 lc 1 lcfirst 1 length 1 link 1 listen 1 local 1 localtime 1 log
1 lstat 1 m// 1 map 1 mkdir 3 msgctl 1 msgget 1 msgrcv 1 msgsnd 1 my 1
next 1 no 1 oct 1 open 1 opendir 1 ord 1 pack 1 package 1 pipe 1 pop 1
pos 1 print 1 printf 1 prototype 1 push 1 q/STRING/ 1 qq/STRING/ 1
quotemeta 1 qw/STRING/ 1 qx/STRING/ 1 rand 1 read 1 readdir 1 readlink
1 recv 1 redo 1 ref 1 rename 1 require 1 reset 1 return 1 reverse 1
rewinddir 1 rindex 1 rmdir 1 s/// 1 scalar 1 seek 1 seekdir 1 select 1
semctl 1 semget 1 semop 1 send 1 setgrent 1 sethostent 1 setnetent 1
setpgrp 1 setpriority 1 setprotoent 1 setpwent 1 setservent 1
setsockopt 1 shift 1 shmctl 1 shmget 1 shmread 1 shmwrite 1 shutdown 1
sin 1 sleep 1 socket 1 socketpair 1 sort 1 splice 1 split 1 sprintf 1
sqrt 1 srand 1 stat 1 study 1 sub 1 substr 1 symlink 1 syscall 1
sysread 1 system 1 syswrite 1 tell 1 telldir 1 tie 1 time 1 times 1
tr/// 1 truncate 1 uc 1 ucfirst 1 umask 1 undef 1 unless 1 unlink 1
unpack 1 unshift 1 untie 1 until 1 use 1 utime 1 values 1 vec 1 wait 1
waitpid 1 wantarray 1 warn 1 while 1 write 1 y/// 1 );


#
# The following hash contains names where the arguments should never
# undergo expansion in the sense of
# $Psh::perlfunc_expand_arguments. For example, any perl keyword where
# an argument is interpreted literally by Perl anyway (such as "use":
# use $yourpackage; is a syntax error) should be on this
# list. Flow-control keywords should be here too.
#
# TODO: Is this list complete ?
#

%perl_builtins_noexpand = qw( continue 1 do 1 for 1 foreach 1 goto 1 if 1 last 1 local 1 my 1 next 1 package 1 redo 1 sub 1 until 1 use 1 while 1);


sub applies {
	my $firstword = @{$_[2]}->[0];
	my $copy = ${$_[1]};

	my $fnname = $firstword;
	my $parenthesized = 0;
	# catch "join(':',@foo)" here as well:
	if ($firstword =~ m/\(/) {
		$parenthesized = 1;
		$fnname = (split('\(', $firstword))[0];
	}
	my $qPerlFunc = 0;
	if ( $builtins &&
		 exists($perl_builtins{$fnname})) {
		my $needArgs = $perl_builtins{$fnname};
		if ($needArgs > 0
			and ($parenthesized
				 or scalar(@{$_[2]}) >= $needArgs)) {
			$qPerlFunc = 1;
		}
	} elsif( $packages &&
			 $fnname =~ /^([a-zA-Z0-9_]+)\:\:([a-zA-Z0-9_:]+)$/) {
		if( $1 eq 'CORE') {
			my $needArgs = $perl_builtins{$2};
			if ($needArgs > 0
				and ($parenthesized or scalar(@{$_[2]}) >= $needArgs)) {
				$qPerlFunc = 1;
			}
		} else {
			$qPerlFunc = (Psh::PerlEval::protected_eval("defined(&{'$fnname'})"))[0];
		}
	} elsif( $fnname =~ /^[a-zA-Z0-9_]+$/) {
		$qPerlFunc = (Psh::PerlEval::protected_eval("defined(&{'$fnname'})"))[0];
	}
	if ( $qPerlFunc ) {
		
		#
		# remove braces containing no whitespace
		# and at least one comma in checking,
		# since they might be for brace expansion
		#

		$copy =~ s/{\S*,\S*}//g;

		if (!$expand_arguments
			or exists($perl_builtins_noexpand{$fnname})
			or $fnname ne $firstword
			or $copy =~ m/[(){},]/) {
			return ${$_[1]};
		} else {                     # no parens, braces, or commas, so  do expansion
			my $ampersand = '';
			my $lastword  = pop @{$_[2]};
			
			if ($lastword eq '&') { $ampersand = '&';         }
			else                  { push @{$_[2]}, $lastword; }
			
			shift @{$_[2]};          # OK to destroy command line since we matched
			
			#
			# No need to do variable expansion, because the whole thing
			# will be evaluated later.
			#

			my @args = Psh::Parser::glob_expansion($_[2]);

			#
			# But we will quote barewords, expressions involving
			# $variables, filenames, and the like:
			#

			foreach (@args) {
				if (&Psh::Parser::needs_double_quotes($_)) {
					$_ = "\"$_\"";
				}
			}

			my $possible_proto = '';

			if (defined($perl_builtins{$fnname})) {
				$possible_proto = prototype("CORE::$fnname");
			} else {
				$possible_proto = prototype($fnname);
			}

			#
			# TODO: Can we use the prototype more fully here?
			#
			my $command = '';

			if (defined($possible_proto) and $possible_proto ne '@') {
				#
				# if it's not just a list operator, better not put in
				# parens, because they could change the semantics
				#
				$command = "$fnname " . join(",",@args);
			} else {
				#
				# Otherwise put in the parens to avoid any ambiguity: we
				# want to pass the given list of args to the function. It
				# would be better in perlfunc eval to get a reference to
				# the function and simply pass the args to it, but I
				# couldn't find any way to make that work with perl
				# builtins. You can't take a reference to CODE::sort, for
				# example.
				#
				$command .= "$fnname(" . join(",",@args) . ')';
			}

			return $command . $ampersand;			}
	}

	return '';
}

sub execute {
	my $todo= $_[3];
	return (sub {
		return Psh::PerlEval::protected_eval($todo,'eval');
	}, [], 0, undef);
}

1;

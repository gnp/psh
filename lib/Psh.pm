package Psh;

use locale;
use Config;
use Cwd;
use Cwd 'chdir';
use FileHandle;
use File::Spec;
use File::Basename;
use Getopt::Std;

use Psh::Util ':all';
use Psh::Locale::Base;
use Psh::OS;
use Psh::Joblist;
use Psh::Job;
use Psh::Completion;
use Psh::Parser;
use Psh::Builtins;
use Psh::PerlEval qw(protected_eval variable_expansion);
use Psh::Prompt;

##############################################################################
##############################################################################
##
## Variables
##
##############################################################################
##############################################################################



#
# Global Variables:
#
# The use vars variables are intended to be accessible to the user via
# explicit Psh:: package qualification. They are documented in the pod
# page. 
#
#
# The other global variables are private, lexical variables.
#

use vars qw($bin $news_file $cmd $echo $host $debugging
			$perlfunc_expand_arguments $executable_expand_arguments
			$VERSION $term @absed_path $readline_saves_history
			$history_file $save_history $history_length $joblist
			$eval_preamble $currently_active $handle_segfaults
            $result_array $which_regexp $ignore_die
			@val @wday @mon @strategies @unparsed_strategies @history
			%text %perl_builtins %perl_builtins_noexpand
			%strategy_which %built_ins %strategy_eval);

# These constants are used in flock().
use constant LOCK_SH => 1; # shared lock (for reading)
use constant LOCK_EX => 2; # exclusive lock (for writing)
use constant LOCK_NB => 4; # non-blocking request (don't wait)
use constant LOCK_UN => 8; # free the lock

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker



#
# Private, Lexical Variables:
#


my @default_strategies     = qw(brace built_in executable fallback_builtin eval);
my @default_unparsed_strategies = qw(comment bang);
my $input;

##############################################################################
##############################################################################
##
## SUBROUTINES: Command-line processing
##
##############################################################################
##############################################################################


#
# variable_expansion is defined above for technical reasons; see
# comments there
#

# EVALUATION STRATEGIES: We have two hashes, %strategy_whichand
#  %strategy_eval; an evaluation strategy called "foo" is implemented
#  by putting a subroutine object in each of these hashes keyed by
#  "foo". The first subroutine should accept a reference to a string
#  (the exact input line) and a reference to an array of strings (the
#  'Psh::decompose'd line, provided as a convenience). It should
#  return a string, which should be null if the strategy does not
#  apply to that input line, and otherwise should be an arbitrary
#  non-null string describing how that strategy applies to that
#  line. It is guaranteed that the string passed in will contain some
#  non-whitespace, and that the first string in the array is
#  non-empty.
#
# The $strategy_eval{foo} routine accepts the same first two arguments
#  and a third argument, which is the string returned by
#  $strategy_which{foo}. It should do the evaluation, and return the
#  result. Note that the $strategy_eval function will be evaluated in
#  an array context. Note also that if $Psh::echo is true, the
#  process() function below will print and store away any
#  result that is not undef.
#
# @Psh::strategies contains the evaluation strategies in order that
# will be called by evl().
#
#
# TODO: Is there a better way to detect Perl built-in-functions and
# keywords than the following? Surprisingly enough,
# defined(&CORE::abs) does not work, i.e., it returns false.
#
# If a value is anything > 1, then it's the minimum number of
# arguments for that function
#

%perl_builtins = qw( -X 1 abs 1 accept 1 alarm 1 atan2 1 bind 1
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

#
# bool matches_perl_binary(string FILENAME)
#
# Returns true if FILENAME referes directly or indirectly to the
# current perl executable
#

sub matches_perl_binary
{
	my ($filename) = @_;

	#
	# Chase down symbolic links, but don't crash on systems that don't
	# have them:
	#

	if ($Config{d_readlink}) {
		my $newfile;
		while ($newfile = readlink($filename)) { $filename = $newfile; }
	}

	if ($filename eq $Config{perlpath}) { return 1; }

	my ($perldev,$perlino) = (stat($Config{perlpath}))[0,1];
	my ($dev,$ino) = (stat($filename))[0,1];

	#
	# TODO: Does the following work on non-Unix OS ?
	#

	if ($perldev == $dev and $perlino == $ino) { return 1; }

	return 0;
}

#
# EVALUATION STRATEGIES:
#

%strategy_which = (
	'bang'     => sub { if (${$_[1]}[0] =~ m/^!/)  { return 'system';  } return ''; },

	'comment'  => sub { if (${$_[1]}[0] =~ m/^\#/) { return 'comment'; } return ''; },
	'brace'    => sub { if (${$_[1]}[0] =~ m/^\{/) { return 'perl evaluation'; } return ''; },
	'built_in' => sub {
	     my $fnname = ${$_[1]}[0];
         no strict 'refs';
         if( $built_ins{$fnname}) {
	         if (Psh::Builtins::_is_aliased($fnname)) {
	                 return "(alias $fnname)";
	         } else {
	                 return "(built_in $fnname)";
             }
         }
         if( ref *{"Psh::Builtins::bi_$fnname"}{CODE} eq 'CODE') {
 	         return "(Psh::Builtins::bi_$fnname)";
         }
		 return '';
	},

    'fallback_builtin' => sub {
		my $fnname = ${$_[1]}[0];
        no strict 'refs';
        if( ref *{"Psh::Builtins::Fallback::bi_$fnname"}{CODE} eq 'CODE') {
			return "(built_in $fnname)";
		}
		return '';
	},

	'auto_resume' => sub {
		my $fnname= ${$_[1]}[0];
        $joblist->enumerate;
        while( my $job= $joblist->each) {
			next if $job->{running};
			my $call= $job->{call};
			if( $call=~ m:/([^/\s]+)\s*$: ) {
				$call= $1;
			}
			return "(auto-resume $call)" if( $call eq $fnname);
		}
        return '';
	},

	'perlfunc' => sub {
		my $firstword = ${$_[1]}[0];
		my $fnname = $firstword;
		my $parenthesized = 0;
		# catch "join(':',@foo)" here as well:
		if ($firstword =~ m/\(/) {
		        $parenthesized = 1;
		        $fnname = (split('\(', $firstword))[0];
		}
		my $qPerlFunc = 0;
		if ( exists($perl_builtins{$fnname})) {
		        my $needArgs = $perl_builtins{$fnname};
    		        if ($needArgs > 0 
			    and ($parenthesized 
				 or scalar(@{$_[1]}) >= $needArgs)) {
			        $qPerlFunc = 1;
			}
		} else {
		        $qPerlFunc = (protected_eval("defined(&{'$fnname'})"))[0];
		}
		if ( $qPerlFunc ) {
			my $copy = ${$_[0]};

			#
			# remove braces containing no whitespace
			# and at least one comma in checking,
			# since they might be for brace expansion
			#

			$copy =~ s/{\S*,\S*}//g;

			if (!$perlfunc_expand_arguments
				or exists($perl_builtins_noexpand{$fnname})
			        or $fnname ne $firstword
				or $copy =~ m/[(){},]/) {
				return ${$_[0]};
			} else {                     # no parens, braces, or commas, so  do expansion
				my $ampersand = '';
				my $lastword  = pop @{$_[1]};

				if ($lastword eq '&') { $ampersand = '&';         }
				else                  { push @{$_[1]}, $lastword; }

				shift @{$_[1]};          # OK to destroy command line since we matched

				#
				# No need to do variable expansion, because the whole thing
				# will be evaluated later.
				#

				my @args = Psh::Parser::glob_expansion($_[1]);

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

				if (defined($possible_proto) and $possible_proto != '@') {
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
	},

	'perlscript' => sub {
		my $script = which(${$_[1]}[0]);

		if (defined($script) and -r $script) {
			#
			# let's see if it really looks like a perl script
			#

			my $sfh = new FileHandle($script);
			my $firstline = <$sfh>;

			$sfh->close();
			chomp $firstline;

			my $filename;
			my $switches;

			if (($filename,$switches) = 
				($firstline =~ m|^\#!\s*(/.*perl)(\s+.+)?$|go)
				and matches_perl_binary($filename)) {
				my $possibleMatch = $script;
				my %bangLineOptions = ();

				if( $switches) {
					$switches=~ s/^\s+//go;
					local @ARGV = split(' ', $switches);

					#
					# All perl command-line options that take aruments as of 
					# Perl 5.00503:
					#

					getopt('DeiFlimMx', \%bangLineOptions); 
				}

				if ($bangLineOptions{w}) { 
					$possibleMatch .= " warnings"; 
					delete $bangLineOptions{w};
				}

				#
				# TODO: We could handle more options. [There are some we
				# can't. -d, -n and -p are popular ones that would be tough.]
				#

				if (scalar(keys %bangLineOptions) > 0) {
					print_debug("[[perlscript: skip $script, options $switches.]]\n");
					return '';
				}

				return $possibleMatch;
			}
		}

		return '';
	},

	'executable' => sub {
		my $executable = which(${$_[1]}[0]);

		if (defined($executable)) { 
			shift @{$_[1]}; # OK to destroy the command line because we're
                            # going to match this strategy
			@newargs= $executable_expand_arguments?variable_expansion($_[1]):
				$_[1];
			@newargs = Psh::Parser::glob_expansion(\@newargs,' ');
			return "$executable @newargs";
		}

		return '';
	},

   'eval' => sub { return 'perl evaluation'; }
);

%strategy_eval = (
	'comment' => sub { return undef; },

	'bang' => sub {
		my ($call) = (${$_[0]} =~ m/!(.*)$/);

		my $fgflag = 1;
		if ($call =~ /^(.*)\&\s*$/) {
			$call= $1;
			$fgflag=0;
		}

		Psh::OS::fork_process( $call, $fgflag, $call, 1);
	    return undef;
	},

	'built_in' => sub {
		my $line= ${shift()};
        my @words= @{shift()};
        my $command= shift @words;
        my $rest= join(' ',@words);
        if( $built_ins{$command}) {
	        return (sub { &{$built_ins{$command}}($rest)}, undef);
        }
        {
	        no strict 'refs';
	        $coderef= *{"Psh::Builtins::bi_$command"};
            return (sub { &{$coderef}($rest,\@words); }, undef );
        }
	},

	'fallback_builtin' => sub {
		my $line= ${shift()};
        my @words= @{shift()};
        my $command= shift @words;
        my $rest= join(' ',@words);
        {
	        no strict 'refs';
	        $coderef= *{"Psh::Builtins::bi_$command"};
            return (sub { &{$coderef}($rest,\@words); }, undef );
        }
	},

	'auto_resume' => sub {
		my $fnname= ${$_[1]}[0];
        $joblist->enumerate;
        my $index=0;
        while( my $job= $joblist->each) {
			next if $job->{running};
			my $call= $job->{call};
			if( $call=~ m:/([^/\s]+)\s*$: ) {
				$call= $1;
			}
			if( $call eq $fnname) {
				Psh::OS::restart_job(1,$index);
				return undef;
			}
			$index++;
		}
        return undef;
	},

	'perlscript' => sub {
		my ($script, @options) = split(' ',$_[2]);
		my @arglist = @{$_[1]};

		shift @arglist; # Get rid of script name
		my $fgflag = 1;

		if (scalar(@arglist) > 0) {
			my $lastarg = pop @arglist;

			if ($lastarg =~ m/\&$/) {
				$fgflag = 0;
				$lastarg =~ s/\&$//;
			}

			if ($lastarg) { push @arglist, $lastarg; }
		}

		print_debug("[[perlscript $script, options @options, args @arglist.]]\n");

		my $pid;

		my %opts = ();
		foreach (@options) { $opts{$_} = 1; }


		return (sub {
			package main;
			# TODO: Is it possible/desirable to put main in the pristine
			# state that it typically is in when a script starts up,
			# i.e. undefine all routines and variables that the user has set?
			
			local @ARGV = @arglist;
			local $^W;

			if ($opts{warnings}) { $^W = 1; }
			else                 { $^W = 0; }

			do $script;

			exit 0;
		}, undef);
	},

	'executable' => sub { return ("$_[2]",undef); },
);

$strategy_eval{brace}= $strategy_eval{eval}= sub {
	my $todo= ${$_[0]};
	return (sub {
		return protected_eval($todo,'eval');
	}, undef);
};

$strategy_eval{perlfunc}= sub {
	my $todo= $_[2];
	return (sub {
		return protected_eval($todo,'eval');
	}, undef);
};


#
# void handle_message (string MESSAGE, string FROM = 'eval')
#
# handles any message that an eval might have returned. Distinguishes
# internal messages from Psh's signal handlers from all other
# messages. It displays internal messages with print_out or does
# nothing with them if FROM = 'main_loop'. It displays other messages with
# print_error, and if FROM = 'main_loop', psh dies in addition.
#

sub handle_message
{
	my ($message, $from) =  @_;

	if (!defined($from)) { $from = 'eval'; }

	chomp $message;

	if ($message) {
		return if ($from eq 'hide');
		if ($message =~ m/^SECRET $bin:(.*)$/s) {
			if ($from ne 'main_loop') { print_out("$1\n"); }
		} else {
			print_error("$from error ($message)!\n");
			if ($from eq 'main_loop') {
				if( $ignore_die) {
					print_error_i18n('internal_error');
				} else {
					die("Internal psh error."); 
				}
			}
		}
	}
}

sub evl {
	my ($line, @use_strats) = @_;

	if (!defined(@use_strats) or scalar(@use_strats) == 0) {
		@use_strats = @strategies;
	}

	my @elements= Psh::Parser::parse_line($line, @use_strats);

	return undef if ! @elements;

	my @result=();
	while( my $element= shift @elements) {
		eval {
			@result= Psh::OS::execute_complex_command($element);
		};
		handle_message($@,$element->[4]);
	}
	return @result;
}

#
# string read_until(PROMPT_TEMPL, string TERMINATOR, subr GET)
#
# Get successive lines via calls to GET until one of those
# entire lines matches the patterm TERMINATOR. Used to implement
# the `<<EOF` multiline quoting construct and brace matching;
#
# TODO: Undo any side effects of, e.g., m//.
#

sub read_until
{
	my ($prompt_templ, $terminator, $get) = @_;
	my $input;
	my $temp;

	$input = '';

	while (1) {
		$temp = &$get(Psh::Prompt::prompt_string($prompt_templ));
		last unless defined($temp);
		last if $temp =~ m/^$terminator$/;
		$input .= $temp;
	}

	return $input;
}

# string read_until_complete(PROMPT_TEMPL, string SO_FAR, subr GET)
#
# Get successive lines via calls to GET until the cumulative input so
# far is not an incomplete expression according to
# incomplete_expr. Prompting is done with PROMPT_TEMPL.
#
# TODO: Undo any side effects of, e.g., m//.
#

sub read_until_complete
{
	my ($prompt_templ, $sofar, $get) = @_;
	my $temp;

	while (1) {
		$temp = &$get(Psh::Prompt::prompt_string($prompt_templ),1);
		if (!defined($temp)) {
			print_error_i18n('input_incomplete',$sofar,$bin);
			return '';
		}
		$sofar .= $temp;
		last if Psh::Parser::incomplete_expr($sofar) <= 0;
	}

	return $sofar;
}


#
# void process(bool Q_PROMPT, subr GET)
#
# Process lines produced by the subroutine reference GET until it
# returns undef. GET must be a reference to a subroutine which takes a
# string argument (the prompt, which may be empty) and returns the
# next line of input, or undef if there is none.
#
# Any output generated is handled by the various print_xxx routines
#
# The prompt is printed only if the Q_PROMPT argument is true.  When
# sourcing files (like .pshrc), it is important to not print the
# prompt string, but for interactive use, it is important to print it.
#
# TODO: Undo any side effects, e.g. done by m//.
#

sub process
{
	my ($q_prompt, $get) = @_;
	local $cmd;

	my $last_result_array = '';
	my $result_array_ref = \@Psh::val;
	my $result_array_name = 'Psh::val';

	while (1) {
		if ($q_prompt) {
			$input = &$get(Psh::Prompt::prompt_string(Psh::Prompt::normal_prompt()));
		} else {
			$input = &$get();
		}

		Psh::OS::reap_children(); # Check wether we have dead children

		$cmd++;

		last unless defined($input);

		if ($input =~ m/^\s*$/) { next; }
		my $continuation = $q_prompt ? Psh::Prompt::continue_prompt() : '';
		if ($input =~ m/<<([a-zA-Z_0-9\-]*)/) {
			my $terminator = $1;
			$input .= read_until($continuation, $terminator, $get);
			$input .= "$terminator\n";
		} elsif (Psh::Parser::incomplete_expr($input) > 0) {
			$input = read_until_complete($continuation, $input, $get);
		}

		chomp $input;
		
		my @result = evl($input);

		my $qEcho = 0;

		if (ref($echo) eq 'CODE') {
			$qEcho = &$echo(@result);
		} elsif (ref($echo)) {
			print_warning_18n('psh_echo_wrong',$bin);
		} else {
			if ($echo) { $qEcho = defined_and_nonempty(@result); }
		}

		if ($qEcho) {
		        # Figure out where we'll save the result:
			if ($last_result_array ne $Psh::result_array) {
				$last_result_array = $Psh::result_array;
				my $what = ref($last_result_array);
				if ($what eq 'ARRAY') {
					$result_array_ref = $last_result_array;
					$result_array_name = 
						find_array_name($result_array_ref);
					if (!defined($result_array_name)) {
						$result_array_name = 'anonymous';
					}
				} elsif ($what) {
					print_warning_18n('psh_result_array_wrong',$bin);
					$result_array_ref = \@Psh::val;
					$result_array_name = 'Psh::val';
				} else { # Ordinary string
					$result_array_name = $last_result_array;				        
					$result_array_name =~ s/^\@//;
				        $result_array_ref = (protected_eval("\\\@$result_array_name"))[0];

				}
			}
			if (scalar(@result) > 1) {
				my $n = scalar(@{$result_array_ref});
				push @{$result_array_ref}, \@result;
				print_out("\$$result_array_name\[$n] <- [", join(',',@result), "]\n");
			} else {
				my $n = scalar(@{$result_array_ref});
				my $res = $result[0];
				push @{$result_array_ref}, $res;
				print_out("\$$result_array_name\[$n] <- $res\n");
			}
		}
	}
}

# string find_array_name ( arrayref REF, string PACKAGE )
#
# If REF is a reference to an array variable in the given PACKAGE or
# any of its subpackages, find the name of that variable and return
# it. PACKAGE defaults to main.

sub find_array_name {
	my ($arref, $pack) = @_;
	if (!defined($pack)) { $pack = "::"; }
	my @otherpacks = ();
	for my $symb ( keys %{$pack} ) {
		if ($symb =~ m/::$/) { 
			push @otherpacks, $symb unless ($pack eq 'main::' and $symb eq 'main::');
		}	     
		elsif (\@{"$pack$symb"} eq $arref) { return "$pack$symb"; }
	}
	for my $subpack (@otherpacks) {
		my $ans = find_array_name($arref,"$pack$subpack");
		if (defined($ans)) { return $ans; }
	}
	return undef;
}

#
# bool defined_and_nonempty(args)
#
# returns true if it has any defined, nonempty args
#

sub defined_and_nonempty
{
	if (!defined(@_))    { return 0; }
	if (scalar(@_) == 0) { return 0; }

	if (scalar(@_) == 1) {
		if (!defined($_[0])) { return 0; }
		if ($_[0] eq '')     { return 0; }

		return 1;
	}

	return 1; # multiple args always true
}


#
# void process_file(string FILENAME)
#
# process() the lines of FILENAME
#

sub process_file
{
	my ($path) = @_;
	
	print_debug("[[PROCESSING FILE $path]]\n");
	
	if (!-r $path) {
		print_error_i18n('cannot_read_script',$path,$bin);
		return;
	}
	
	my $pfh = new FileHandle($path,'r');
	
	if (!$pfh) {
		print_error_i18n('cannot_open_script',$path,$bin);
		return;
	}
	
	flock($pfh, LOCK_SH);
	
	process(0, sub { return <$pfh>; }); # don't prompt
	
	flock($pfh, LOCK_UN);
	$pfh->close();
	
	print_debug("[[FINISHED PROCESSING FILE $path]]\n");
}

#
# string iget(string PROMPT [, boolean returnflag])
#
# Interactive line getting routine. If we have a
# Term::ReadLine instance, use it and record the
# input into the history buffer. Otherwise, just
# grab an input line from STDIN.
#
# If returnflag is true, iget will return after
# the user pressed ^C
#
# readline() returns a line WITHOUT a "\n" at the
# end, and <STDIN> returns one WITH a "\n", UNLESS
# the end of the input stream occurs after a non-
# newline character. So, first we chomp() the
# output of <STDIN> (if we aren't using readline()),
# and then we tack the newline back on in both
# cases. Other code later strips it off if necessary.
#
# iget() uses PROMPT as the prompt; this may be the empty string if no
# prompting is necessary.
#
# TODO: Handle ^D nicely (i.e. allow log out or at least print "\n";)
#

sub iget
{
	my $prompt = shift;
	my $returnflag= shift;
	my $prompt_pre= '';
	my $line;
	my $sigint = 0;

	# Additional newline handling for prompts as Term::ReadLine::Perl
	# cannot use them properly
	if( $term->ReadLine eq 'Term::ReadLine::Perl' &&
		$prompt=~ /^(.*\n)([^\n]+)$/) {
		$prompt_pre=$1;
		$prompt=$2;
	}

	Psh::OS::setup_readline_handler();
 
	do {
		$sigint= 0 if ($sigint);
		# Trap ^C in an eval.  The sighandler will die which will be
		# trapped.  Then we reprompt
		if ($term) {
			print $prompt_pre if $prompt_pre;
			eval { $line = $term->readline($prompt); };
		} else {
			eval {
				print $prompt_pre if $prompt_pre;
				print $prompt if $prompt;
				$line = <STDIN>;
			}
		}
		if( $@) {
			if( $@ =~ /Signal INT/) {
				$sigint= 1;
				print_out_i18n('readline_interrupted');
				if( $returnflag) {
					Psh::OS::remove_readline_handler();
					return undef;
				}
				next;
			} else {
				handle_message( $@, 'main_loop');
			}
		}
	} while ($sigint);

	Psh::OS::remove_readline_handler();

	chomp $line;

# [ gtw: Why monkey with the input? If we take out whitespace now,
#   we'll never know if it was there. Better wait.
# ]

#	$line =~ s/^\s+//;
#	$line =~ s/\s+$//;

	if ($term and $line !~ m/^\s*$/) {
		$term->addhistory($line); 

		if ($save_history && !$readline_saves_history) {
			push(@history, $line);
		}
	}
	
	return $line . "\n";         # This is expected by other code.
}


#
# string news()
#
# Return the news

sub news 
{
	if (-r $news_file) {
		# Backticks replaced to be portable
		my $text='';
		open( FILE, "< $news_file");
		while( <FILE>) { $text.=$_; }
		close( FILE);
		return $text;
	} else {
		return '';
	}
}


#
# void minimal_initialize()
#
# Initialize just enough to be able to read the .pshrc file; leave
# uncritical user-accessible variables until later in case the user
# sets them in .pshrc.

sub minimal_initialize
{
	$|                           = 1;                # Set ouput autoflush on

	#
    # Set up accessible psh:: package variables:
	#

    @strategies                  = @default_strategies;
	@unparsed_strategies         = @default_unparsed_strategies;
	$eval_preamble               = 'package main;';
    $currently_active            = 0;
	$result_array                = '';
	$perlfunc_expand_arguments   = 0;
	$executable_expand_arguments = 1;
	$which_regexp                = '^[-a-zA-Z0-9_.~+]*$'; #'
	$cmd                         = 1;

	$bin                         = basename($0);

	$news_file                   = "$bin.NEWS";

	# I think that the "SHELL" environment variable is supposed to
	# be the login shell (at least no other shell I tried set it), so
	# lets set some other variable:
	$ENV{CURRENT_SHELL} = $0;
	$ENV{PWD} = cwd;

	Psh::OS::setup_signal_handlers();

	# The following accessible variables are undef during the
	# .pshrc file:
	undef $prompt;
	undef $prompt_cont;
	undef $save_history;
	undef $history_length;
	undef $longhost;
	undef $host;
	undef $history_file;

	$joblist= new Psh::Joblist();

	@val = ();

	Psh::Locale::Base::init();
}

#
# void finish_initialize()
#
# Set the remaining psh:: package variables if they haven't been set
# in the .pshrc file, and do other "late" initialization steps that
# depend on these variable values.

sub finish_initialize
{
	Psh::OS::setup_sigsegv_handler if $Psh::handle_segfaults;

	$save_history    = 1               if !defined($save_history);
	$history_length  = $ENV{HISTSIZE} || 50 if !defined($history_length);

	if (!defined($longhost)) {
		$longhost                    = Psh::OS::get_hostname();
		chomp $longhost;
	}
	if (!defined($host)) {
		$host= $longhost;
		$host= $1 if( $longhost=~ /([^\.]+)\..*/);
	}
	if (!defined($history_file)) {
		$history_file                = File::Spec->catfile(Psh::OS::get_home_dir(),".${bin}_history");
	}


    #
    # Set up Term::ReadLine:
    #
	eval "use Term::ReadLine;";

	if ($@) {
		$term = undef;
		print_error_i18n(no_readline);
	} else {
		eval { $term= Term::ReadLine->new('psh'); };
		if( $@) {
			# Try one more time after a second, maybe the tty is
			# not setup
			sleep 1;
			eval { $term= Term::ReadLine->new('psh'); };
			if( $@) {
				print_error_i18n(readline_error,$@);
				$term= undef;
			}
		}
		if( $term) {
			$term->MinLine(10000);   # We will handle history adding
			# ourselves (undef causes trouble). 
			$term->ornaments(0);
			print_debug("Using ReadLine: ", $term->ReadLine(), "\n");
			if ($term->ReadLine() eq "Term::ReadLine::Gnu") {
				$readline_saves_history = 1;
				$term->StifleHistory($history_length); # Limit history
			}
			&Psh::Completion::init();
			$term->Attribs->{completion_function} =
				\&Psh::Completion::completion;
		}
	}

    #
    # Set up Term::Size:
    #
	eval "use Term::Size 'chars'";

	if ($@) {
		print_debug("Term::Size not available. Trying Term::ReadKey\n");   
		eval "use Term::ReadKey";
		if( $@) {
			print_debug("Term::ReadKey not available - no resize handling!\n");
		}
	}
	else    { print_debug("Using &Term::Size::chars().\n"); }

	Psh::OS::reinstall_resize_handler();
	# ReadLine objects often mess with the SIGWINCH handler

	if (defined($term) and $save_history) {
		if ($readline_saves_history) {
			$term->ReadHistory($history_file);
		} else {
			my $fhist = new FileHandle($history_file);
			if (defined($fhist)) {
				flock($fhist, LOCK_SH);
				while (<$fhist>) {
					$term->addhistory(chomp($_));
				}
				flock($fhist, LOCK_UN);
				$fhist->close();
			}
		}
	}
}


#
# void process_rc()
#
# Search for and process .pshrc files.
#

sub process_rc
{
	my $opt_r= shift;
	my @rc;
	my $rc_name = ".pshrc";

	print_debug("[ LOOKING FOR .pshrc ]\n");

	if ($opt_r) {
		push @rc, $opt_r;
	} else {
		my $home= Psh::OS::get_home_dir();
		if ($home) { push @rc, File::Spec->catfile($home,$rc_name) };
		push @rc, "$rc_name" unless $home eq cwd;
	}

	foreach my $rc (@rc) {
		if (-r $rc) {
			print_debug("[ PROCESSING $rc ]\n");
			process_file($rc);
		}
	}
}


#
# void process_args()
#
# Process files listed on command-line.
#

sub process_args
{
	print_debug("[ PROCESSING @ARGV FILES ]\n");

	foreach my $arg (@ARGV) {
		if (-r $arg) {
			print_debug("[ PROCESSING $arg ]\n");
			process_file($arg);
		}
	}
}


#
# void main_loop()
#
# Determine whether or not we are operating interactively,
# set up the input routine accordingly, and process the
# input.
#

sub main_loop
{
	my $interactive = (-t STDIN) and (-t STDOUT);
	my $get;

	print_debug("[[STARTING MAIN LOOP]]\n");

	if ($interactive) { $get = \&iget;                  }
	else              { $get = sub { return <STDIN>; }; }

	process($interactive, $get);
}

# bool is_number(ARG)
#
# Return true if ARG is a number
#

sub is_number
{
	my $test = shift;
	return defined($test) && $test &&
		$test=~/^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/o;
}

#
# void symbols()
#
# Print out the symbols of each type used by a package. Note: in testing,
# it bears out that the filehandles are present as scalars, and that arrays
# are also present as scalars. The former is not particularly surprising,
# since they are implemented as tied objects. But, use vars qw(@X) causes
# both @X and $X to show up in this display. This remains mysterious.
#

sub symbols
{
	my $pack = shift;
	my (@ref, @scalar, @array, @hash, @code, @glob, @handle);
	my @sym;

	{
		no strict qw(refs);
		@sym = keys %{*{"${pack}::"}};
	}

	for my $sym (sort @sym) {
		next unless $sym =~ m/^[a-zA-Z]/; # Skip some special variables
		next if     $sym =~ m/::$/;       # Skip all package hashes

		{
			no strict qw(refs);

			push @ref,    "\$$sym" if ref *{"${pack}::$sym"}{SCALAR} eq 'REF';
			push @scalar, "\$$sym" if ref *{"${pack}::$sym"}{SCALAR} eq 'SCALAR';
			push @array,  "\@$sym" if ref *{"${pack}::$sym"}{ARRAY}  eq 'ARRAY';
			push @hash,   "\%$sym" if ref *{"${pack}::$sym"}{HASH}   eq 'HASH';
			push @code,   "\&$sym" if ref *{"${pack}::$sym"}{CODE}   eq 'CODE';
			push @handle, "$sym"   if ref *{"${pack}::$sym"}{FILEHANDLE};
		}
	}

	print_out("Reference: ", join(' ', @ref),    "\n");
	print_out("Scalar:    ", join(' ', @scalar), "\n");
	print_out("Array:     ", join(' ', @array),  "\n");
	print_out("Hash:      ", join(' ', @hash),   "\n");
	print_out("Code:      ", join(' ', @code),   "\n");
	print_out("Handle:    ", join(' ', @handle), "\n");
}


##############################################################################
##############################################################################
##
## SUBROUTINES: Support
##
##############################################################################
##############################################################################

#
# void my_system(string COMMAND_LINE)
#
# Executes COMMAND_LINE via system, noticing and stripping final '&'
# to allow jobcontrol
#

sub my_system
{
	my($call) = @_;

	#
	# TODO: This is an absolute hack... we need
	# a full parser for quoting and all special
	# characters soon!!
	#
	# Well, Psh::Parser::decompose is pretty flexible now; perhaps
	# this function ought to be modified to take the fgflag as a
	# parameter, and the calls changed to have done the parsing
	# already, passing only the actyal string to be exec'ed and
	# the fgflag. Just one way maybe to skin the cat...

	my $fgflag = 1;

	if ($call =~ /^(.*)\&\s*$/) {
		$call= $1;
		$fgflag=0;
	}

	Psh::OS::fork_process( $call, $fgflag, $call);
}

#
# End of file.
#

1;


# The following is for Emacs - I hope it won't annoy anyone
# but this could solve the problems with different tab widths etc
#
# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# c-basic-offset:4
# perl-label-offset:0
# perl-indent-level:4
# End:



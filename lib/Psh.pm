package Psh;

use locale;
use Config;
use FileHandle;
use File::Spec;
use File::Basename;

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

use vars qw($bin $cmd $echo $host $debugging
		    $executable_expand_arguments
			$VERSION $term @absed_path $readline_saves_history
			$history_file $save_history $history_length $joblist
			$eval_preamble $currently_active $handle_segfaults
			$result_array $which_regexp $ignore_die $old_shell
		    $login_shell $window_title
            $interactive
			@val @wday @mon @strategies @unparsed_strategies @history
            @executable_noexpand
			%text %perl_builtins %perl_builtins_noexpand
			%strategy_which %built_ins %strategy_eval %fallback_builtin);

# These constants are used in flock().
use constant LOCK_SH => 1; # shared lock (for reading)
use constant LOCK_EX => 2; # exclusive lock (for writing)
use constant LOCK_NB => 4; # non-blocking request (don't wait)
use constant LOCK_UN => 8; # free the lock

$VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker



#
# Private, Lexical Variables:
#


my @default_strategies = qw(brace built_in executable eval);
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
# Contains names of fallback builtins we support
#

%fallback_builtin = ('ls'=>1, 'env'=>1 );

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
         if( ref *{"Psh::Builtins::bi_$fnname"}{CODE} eq 'CODE') {
 	         return "(Psh::Builtins::bi_$fnname)";
         }
         if( $built_ins{$fnname}) {
			 eval 'use Psh::Builtins::'.ucfirst($fnname);
			 if ($@) {
				 Psh::Util::print_error_i18n('builtin_failed',$@);
			 }
             return "(Psh::Builtins::".ucfirst($fnname)."::bi_$fnname)";
		 }
		 return '';
	},

	'executable' => sub {
		my $executable = which(${$_[1]}[0]);

		return "$executable" if defined($executable);

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
        no strict 'refs';
        if( ref *{"Psh::Builtins::bi_$command"}{CODE} eq 'CODE') {
			$coderef= *{"Psh::Builtins::bi_$command"};
        } elsif( $built_ins{$command}) {
			$coderef= *{'Psh::Builtins::'.ucfirst($command)."::bi_$command"};
		}
        return (sub { &{$coderef}($rest,\@words); }, [], 0, undef );
	},

	'executable' => sub {
		my @args=@_;
		my @newargs= @{$args[1]};
		if ($executable_expand_arguments) {
			my $flag=0;

			foreach my $re (@executable_noexpand) {
				if ($args[2]=~ m{$re}) {
					$flag=1;
					last;
				}
			}
			@newargs= variable_expansion(\@newargs) unless $flag;
		}
		@newargs = Psh::Parser::glob_expansion(\@newargs);
		@newargs = map { Psh::Parser::unquote($_)} @newargs;

		return ("$args[2] @newargs", ["$args[2]",@newargs], 0, undef, );
	},
);

$strategy_eval{brace}= $strategy_eval{eval}= sub {
	my $todo= ${$_[0]};

	if( $_[3]) { # we are second or later in a pipe
		my $code;
		$todo=~ s/\} ?([qg])\s*$/\}/;
		my $mods= $1 || '';
		if( $mods eq 'q' ) { # non-print mode
			$code='while(<STDIN>) { @_= split /\s+/; '.$todo.' ; }';
		} elsif( $mods eq 'g') { # grep mode
			$code='while(<STDIN>) { @_= split /\s+/; print $_ if eval { '.$todo.' }; } ';
		} else {
			$code='while(<STDIN>) { @_= split /\s+/; '.$todo.' ; print $_ if $_; }';
		}
		return (sub {return protected_eval($code,'eval'); }, [], 0, undef);
    } else {
		return (sub {
			return protected_eval($todo,'eval');
		}, [], 0, undef);
	}
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

	# In case multi-line input is passed to evl
	if (ref $line eq 'ARRAY') {
		foreach (@$line) {
			evl($_,@use_strats);
		}
		return;
	}

	if (!@use_strats) {
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
		$temp = &$get(Psh::Prompt::prompt_string($prompt_templ),
					  1,\&Psh::Prompt::pre_prompt_hook);
		if (!defined($temp)) {
			print_error_i18n('input_incomplete',$sofar,$bin);
			return '';
		}
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
		$temp = &$get(Psh::Prompt::prompt_string($prompt_templ),1,
					  \&Psh::Prompt::pre_prompt_hook);
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

	my $control_d_counter=0;

	while (1) {
		if ($q_prompt) {
			$input = &$get(Psh::Prompt::prompt_string(Psh::Prompt::normal_prompt()), 0, \&Psh::Prompt::pre_prompt_hook);
		} else {
			$input = &$get();
		}

		Psh::OS::reap_children(); # Check wether we have dead children

		$cmd++;

		unless (defined($input)) {
			last unless $interactive;
			print STDOUT "\n";
			$control_d_counter++;
			my $control_d_max=$ENV{IGNOREEOF}||0;
			if ($control_d_max !~ /^\d$/) {
				$control_d_max=10;
			}
			Psh::OS::exit() if ($control_d_counter>=$control_d_max);
			next;
		}
		$control_d_counter=0;

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
			print_warning_i18n('psh_echo_wrong',$bin);
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
					print_warning_i18n('psh_result_array_wrong',$bin);
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

	print_debug("[PROCESSING FILE $path]\n");
	$interactive=0;

	if (!-r $path) {
		print_error_i18n('cannot_read_script',$path,$bin);
		return;
	}

	my $pfh = new FileHandle($path,'r');

	if (!$pfh) {
		print_error_i18n('cannot_open_script',$path,$bin);
		return;
	}

	eval { flock($pfh, LOCK_SH); };

	process(0, sub {
				my $txt=<$pfh>;
				print_debug_class('f',$txt);
				return $txt;
			}); # don't prompt

	eval { flock($pfh, LOCK_UN); };
	$pfh->close();

	$interactive=1;

	print_debug("[FINISHED PROCESSING FILE $path]\n");
}

#
# string iget(string PROMPT [, boolean returnflag [, code prompt_hook]])
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

sub iget
{
	my $prompt = shift;
	my $returnflag= shift;
	my $prompt_hook= shift;

	my $prompt_pre= '';
	my $line;
	my $sigint = 0;
	$interactive=1;

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
			&$prompt_hook if $prompt_hook;
			print $prompt_pre if $prompt_pre;
			eval { $line = $term->readline($prompt); };
		} else {
			eval {
				&$prompt_hook if $prompt_hook;
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
	Psh::OS::reinstall_resize_handler();

	return undef unless defined $line;
	chomp $line;

    add_history($line);
	return $line . "\n";         # This is expected by other code.
}

sub add_history
{
	my $line=shift;
	return if !$line or $line =~ /^\s*$/;
	if (!@history || $history[$#history] ne $line) {
		$term->addhistory($line) if $term;
		push(@history, $line);
		if( @Psh::history>$Psh::history_length) {
			splice(@Psh::history,0,-$Psh::history_length);
		}
	}
}

sub save_history
{
	Psh::Util::print_debug_class('o',"[Saving history]\n");
	if( $Psh::save_history) {
		if ($Psh::readline_saves_history) {
			$Psh::term->WriteHistory($Psh::history_file);
		} else {
			my $fhist = new FileHandle($Psh::history_file, 'a');
			if (defined($fhist)) {
				eval { flock($fhist, LOCK_EX); };
				foreach (@Psh::history) {
					$fhist->print("$_\n");
				}
				eval { flock($fhist, LOCK_UN); };
				$fhist->close();
			}
		}
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
	$|                           = 1;                # Set output autoflush on

	#
	# Set up accessible psh:: package variables:
	#

	@strategies                  = @default_strategies;
	@unparsed_strategies         = @default_unparsed_strategies;
	$eval_preamble               = 'package main;';
	$currently_active            = 0;
	$result_array                = '';
	$executable_expand_arguments = 1;
	$which_regexp                = '^[-a-zA-Z0-9_.~+]*$'; #'

	if ($]>=5.005) {
		eval {
			$which_regexp= qr/$which_regexp/; # compile for speed reasons
		}
	}

	$cmd                         = 1;

	$bin                         = basename($0);

	$old_shell = $ENV{SHELL} if $ENV{SHELL};
	$ENV{SHELL} = $0;
	$ENV{PWD} = Psh::OS::getcwd();
	$ENV{PSH_TITLE} = $bin;

	Psh::OS::inc_shlvl();
	Psh::OS::setup_signal_handlers();
	Psh::Builtins::build_autoload_list();

	$Psh::window_title='\w';

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
	@history= ();

	# I don't know wether this should really be pre-initialized
	@executable_noexpand= ('whois','/ezmlm-','/mail$','/mailx$',
						   '/pine$');

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
	Psh::OS::setup_sigsegv_handler() if $Psh::handle_segfaults;

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
		$history_file= File::Spec->catfile(Psh::OS::get_home_dir(),
										   ".${bin}_history");
	}


	if (-t STDIN) {
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
				print_debug_class('i',"[Using ReadLine: ", $term->ReadLine(), "]\n");
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
			print_debug_class('i',"[Term::Size not available. Trying Term::ReadKey\n]");
			eval "use Term::ReadKey";
			if( $@) {
				print_debug_class('i',"[Term::ReadKey not available]\n");
			}
		}
		else    { print_debug_class('i',"[Using &Term::Size::chars().]\n"); }

		Psh::OS::reinstall_resize_handler();
	}
	# ReadLine objects often mess with the SIGWINCH handler

	if (defined($term) and $save_history) {
		if ($readline_saves_history) {
			$term->ReadHistory($history_file);
		} else {
			my $fhist = new FileHandle($history_file,'r');
			if (defined($fhist)) {
				eval { flock($fhist, LOCK_SH); };
				while (<$fhist>) {
					chomp;
					$term->addhistory($_);
				}
				eval { flock($fhist, LOCK_UN); };
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

	if ($opt_r) {
		push @rc, $opt_r;
	} else {
		push @rc, Psh::OS::get_rc_files();
	}

	foreach my $rc (@rc) {
		if (-r $rc) {
			print_debug_class('i',"[PROCESSING $rc]\n");
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
	print_debug_class('i',"[PROCESSING @ARGV FILES]\n");

	foreach my $arg (@ARGV) {
		if (-r $arg) {
			print_debug('i',"[PROCESSING $arg]\n");
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

	print_debug_class('i',"[STARTING MAIN LOOP]\n");

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



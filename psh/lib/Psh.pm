package Psh;

use locale;
require File::Spec;
require Psh::Util;
require Psh::Locale;
require Psh::Strategy;
require Psh::OS;
require Psh::Joblist;
require Psh::Parser;
require Psh::PerlEval;
require Psh::Prompt;
require Psh::Options;

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

use vars qw($bin $cmd $host $debugging
			$term @absed_path
			$eval_preamble $currently_active
			$result_array $which_regexp $old_shell
		    $login_shell $window_title
            $interactive $current_options
			@val @history %text );

#
# Private, Lexical Variables:
#


my ($input,$readline_saves_history);
##############################################################################
##############################################################################
##
## SUBROUTINES: Command-line processing
##
##############################################################################
##############################################################################

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
			if ($from ne 'main_loop') { Psh::Util::print_out("$1\n"); }
		} else {
			Psh::Util::print_error("$from error ($message)!\n");
			if ($from eq 'main_loop') {
				if( Psh::Options::get_option('ignoredie')) {
					Psh::Util::print_error_i18n('internal_error');
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

	my @elements= eval { Psh::Parser::parse_line($line, @use_strats) };
	Psh::Util::print_debug_class('e',"(evl) Error: $@") if $@;
	return undef unless @elements;

	my ($success,$result)= _evl(@elements);
	Psh::Util::print_debug_class('s',"Success: $success\n");
	return ($success,@$result);
}

sub _evl {
	my @elements= @_;
	my @result=();
	my $trace= Psh::Options::get_option('trace');
	while( my $element= shift @elements) {
		my @tmp= @$element;
		my $type= shift @tmp;
		if ($type == Psh::Parser::T_EXECUTE()) {
			if ($trace) {
				for (my $i=1; $i<@tmp; $i++) {
					print STDERR "+ $tmp[$i][4]\n";
				}
			}
			eval {
				@result= Psh::OS::execute_complex_command(\@tmp);
			};
			handle_message($@);
		} elsif ($type == Psh::Parser::T_OR()) {
			return @result if @result and $result[0]; # we already had success
		} elsif ($type == Psh::Parser::T_AND()) {
			return (0) unless @result;
			next if ($result[0]); # we last had success
			return (0);
		} else {
			Psh::Util::print_error("evl: Don't know type $type\n");
		}
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

	my @input;

	while (1) {
		$temp = &$get(Psh::Prompt::prompt_string($prompt_templ),
					  1,\&Psh::Prompt::pre_prompt_hook);
		if (!defined($temp)) {
			Psh::Util::print_error_i18n('input_incomplete',$sofar,$bin);
			return '';
		}
		last if $temp =~ m/^$terminator$/;
		push @input, $temp;
	}

	return join('',@input);
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
	my @input=();

	while (1) {
		$temp = &$get(Psh::Prompt::prompt_string($prompt_templ),1,
					  \&Psh::Prompt::pre_prompt_hook);
		if (!defined($temp)) {
			Psh::Util::print_error_i18n('input_incomplete',$sofar,$bin);
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
		Psh::OS::check_terminal_size() if $interactive;

		$cmd++;

		unless (defined($input)) {
			last unless $interactive;
			print STDOUT "\n";
			$control_d_counter++;
			my $control_d_max=$ENV{IGNOREEOF}||0;
			if ($control_d_max !~ /^\d$/) {
				$control_d_max=10;
			}
			Psh::OS::exit_psh() if ($control_d_counter>=$control_d_max);
			next;
		}
		$control_d_counter=0;

		next unless $input;
		next if $input=~ m/^\s*$/;

		if ($input =~ m/<<([a-zA-Z_0-9\-]*)/) {
			my $terminator = $1;
			my $continuation = $q_prompt ? Psh::Prompt::continue_prompt() : '';
			$input = join('',$input,
						  read_until($continuation, $terminator, $get),
						  $terminator,"\n");
		} elsif (Psh::Parser::incomplete_expr($input) > 0) {
			my $continuation = $q_prompt ? Psh::Prompt::continue_prompt() : '';
			$input = read_until_complete($continuation, $input, $get);
		}

		chomp $input;
		my ($success,@result) = evl($input);

		my $qEcho = 0;
		my $echo= Psh::Options::get_option('echo');

		if (ref($echo) eq 'CODE') {
			$qEcho = &$echo(@result);
		} elsif (ref($echo)) {
			Psh::Util::print_warning_i18n('psh_echo_wrong',$bin);
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
					Psh::Util::print_warning_i18n('psh_result_array_wrong',$bin);
					$result_array_ref = \@Psh::val;
					$result_array_name = 'Psh::val';
				} else { # Ordinary string
					$result_array_name = $last_result_array;
					$result_array_name =~ s/^\@//;
					$result_array_ref = (Psh::PerlEval::protected_eval("\\\@$result_array_name"))[0];
				}
			}
			if (scalar(@result) > 1) {
				my $n = scalar(@{$result_array_ref});
				push @{$result_array_ref}, \@result;
				if ($interactive) {
					my @printresult=();
					foreach my $val (@result) {
						if (defined $val) {
							push @printresult,qq['$val'];
						} else {
							push @printresult,qq[undef];
						}
					}
					Psh::Util::print_out("\$$result_array_name\[$n] = [", join(',',@printresult), "]\n");
				}
			} else {
				my $n = scalar(@{$result_array_ref});
				my $res = $result[0];
				push @{$result_array_ref}, $res;
				Psh::Util::print_out("\$$result_array_name\[$n] = \"$res\"\n") if $interactive;
			}
			if (@{$result_array_ref}>100) {
				shift @{$result_array_ref};
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
	my $path= shift;

	Psh::Util::print_debug("[PROCESSING FILE $path]\n");
	local $interactive=0;

	if (!-r $path) {
		Psh::Util::print_error_i18n('cannot_read_script',$path,$bin);
		return;
	}

	unless (open(FILE, "< $path")) {
		Psh::Util::print_error_i18n('cannot_open_script',$path,$bin);
		return;
	}

	Psh::OS::lock(*FILE);

	if ($Psh::debugging=~ /f/ or
		$Psh::debugging eq '1') {
		process(0, sub {
					my $txt=<FILE>;
					Psh::Util::print_debug_class('f',$txt);
					return $txt;
				}); # don't prompt
	} else {
		process(0, sub { my $txt=<FILE>;$txt });
	}

	Psh::OS::unlock(*FILE);
	close(FILE);

	Psh::Util::print_debug("[FINISHED PROCESSING FILE $path]\n");
}

sub process_variable {
	my $var= shift;
	local $Psh::interactive=0;
	my @lines;
	if (ref $var eq 'ARRAY') {
		@lines=@$var;
	} else {
		@lines= split /\n/, $var;
		@lines= map { $_."\n" } @lines;
	}
	process(0, sub { shift @lines });
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

	LINE: do {
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
			};
		}
		if( $@) {
			if( $@ =~ /Signal INT/) {
				$sigint= 1;
				Psh::Util::print_out_i18n('readline_interrupted');
				if( $returnflag) {
					Psh::OS::remove_readline_handler();
					return undef;
				}
			} else {
				handle_message( $@, 'iget');
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
		my $len= Psh::Options::get_option('histsize');
		$term->addhistory($line) if $term;
		push(@history, $line);
		if( @Psh::history>$len) {
			splice(@Psh::history,0,-$len);
		}
	}
}

sub save_history
{
	return unless $term;
	Psh::Util::print_debug_class('o',"[Saving history]\n");
	if( Psh::Options::get_option('save_history')) {
		my $file= Psh::Options::get_option('history_file');
		return unless $file;
		if ($Psh::readline_saves_history) {
			$term->StifleHistory(Psh::Options::get_option('histsize'));
			$Psh::term->WriteHistory($file);
		} else {
			if (open(F_HISTORY,">> $file")) {
				Psh::OS::lock(*F_HISTORY, Psh::OS::LOCK_EX());
				foreach (@Psh::history) {
					print F_HISTORY $_;
					print F_HISTORY "\n";
				}
				Psh::OS::unlock(*F_HISTORY);
				close(F_HISTORY);
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

	$eval_preamble               = 'package main;';
	$currently_active            = 0;
	$result_array                = '';
	$which_regexp                = '^[-a-zA-Z0-9_.~+]+$'; #'

	if ($]>=5.005) {
		eval {
			$which_regexp= qr($which_regexp); # compile for speed reasons
		};
		Psh::Util::print_debug_class('e',"(minimal_init) Error: $@") if $@;
	}

	$cmd                         = 1;
	my @tmp= File::Spec->splitdir($0);
	$bin= pop @tmp;
	Psh::Options::set_option('history_file',
							 File::Spec->catfile(Psh::OS::get_home_dir(),
												 '.'.$Psh::bin.'_history'));

	$old_shell = $ENV{SHELL} if $ENV{SHELL};
	$ENV{SHELL} = $0;
	$ENV{OLDPWD}= $ENV{PWD} = Psh::OS::getcwd_psh();

	Psh::OS::inc_shlvl();
	Psh::OS::setup_signal_handlers();

	# The following accessible variables are undef during the
	# .pshrc file:
	undef $longhost;
	undef $host;

	@val = ();
	@history= ();

	Psh::Strategy::setup_defaults();
}

#
# void finish_initialize()
#
# Set the remaining psh:: package variables if they haven't been set
# in the .pshrc file, and do other "late" initialization steps that
# depend on these variable values.

sub finish_initialize
{
	Psh::OS::setup_sigsegv_handler() if
	  Psh::Options::get_option('ignoresegfault');

	if (!defined($longhost)) {
		$longhost                    = $ENV{HOSTNAME}||Psh::OS::get_hostname();
		chomp $longhost;
	}
	if (!defined($host)) {
		$host= $longhost;
		$host= $1 if( $longhost=~ /([^\.]+)\..*/);
	}
	$ENV{HOSTNAME}= $host;
}

sub initialize_interactive_mode {
	if (-t STDIN) {
		#
		# Set up Term::ReadLine:
		#
		eval { require Term::ReadLine; };
		if ($@) {
			$term = undef;
			Psh::Util::print_error_i18n('no_readline');
		} else {
			eval { $term= Term::ReadLine->new('psh'); };
			if( $@) {
				# Try one more time after a second, maybe the tty is
				# not setup
				sleep 1;
				eval { $term= Term::ReadLine->new('psh'); };
				if( $@) {
					Psh::Util::print_error_i18n('readline_error',$@);
					$term= undef;
				}
			}
			if( $term) {
				$term->MinLine(10000);   # We will handle history adding
				# ourselves (undef causes trouble).
				$term->ornaments(0);
				Psh::Util::print_debug_class('i',"[Using ReadLine: ", $term->ReadLine(), "]\n");
				if ($term->ReadLine() eq "Term::ReadLine::Gnu") {
					$readline_saves_history = 1;
				}
				my $attribs= $term->Attribs;
				$attribs->{completion_function} =
				  \&completion_dummy;

				my $word_break=" \\\n\t\"&{}('`\$\%\@~<>=;|/";
				$attribs->{special_prefixes}= "\$\%\@\~\&";
				$attribs->{word_break_characters}= $word_break;
				$attribs->{completer_word_break_characters}= $word_break ;
			}
		}

		Psh::OS::install_resize_handler();
		Psh::OS::reinstall_resize_handler();
		# ReadLine objects often mess with the SIGWINCH handler

		setup_term_misc();
	}

	if (defined($term) and Psh::Options::get_option('save_history')) {
		my $file= Psh::Options::get_option('history_file');
		return unless $file;
		if ($readline_saves_history) {
			$term->StifleHistory(Psh::Options::get_option('histsize'));
			$term->ReadHistory($file);
		} else {
			if (open(F_HISTORY,"< $file")) {
				Psh::OS::lock(*F_HISTORY);
				while (<F_HISTORY>) {
					chomp;
					$term->addhistory($_);
				}
				Psh::OS::unlock(*F_HISTORY);
				close(F_HISTORY);
			}
		}
	}
}


#
# We're used for the first TAB completion - load
# the real completion module and call it
#
sub completion_dummy {
	my @args= @_;

	require Psh::Completion;
	Psh::Completion::init();
    $term->Attribs->{completion_function} =
	  \&Psh::Completion::completion;
	return Psh::Completion::completion(@_);
}

sub setup_term_misc {
	return unless $term;
	if ($term->can('add_defun')) { # Term::ReadLine::Gnu
		$term->add_defun('run-help', \&run_help);
		$term->parse_and_bind("\"\eh\":run-help"); # bind to ESC-h
	}
}

sub run_help {
	require Psh::Builtins::Help;
	my $line= substr($term->Attribs->{line_buffer},0,$term->Attribs->{end});
	Psh::Builtins::Help::any_help($line);
}

#
# void process_rc()
#
# Search for and process .pshrc files.
#

sub process_rc
{
	my $opt_f= shift;
	my @rc;

	if ($opt_f) {
		push @rc, $opt_f;
	} else {
		push @rc, Psh::OS::get_rc_files();
	}

	foreach my $rc (@rc) {
		if (-r $rc) {
			Psh::Util::print_debug_class('i',"[PROCESSING $rc]\n");
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
	Psh::Util::print_debug_class('i',"[PROCESSING @ARGV FILES]\n");

	foreach my $arg (@ARGV) {
		if (-r $arg) {
			Psh::Util::print_debug('i',"[PROCESSING $arg]\n");
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

	Psh::Util::print_debug_class('i',"[STARTING MAIN LOOP]\n");

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
	return defined($test) && !ref($test) &&
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

package Psh::Strategy::Fallback_builtin;

=item * C<fallback_builtin>

If the first word of the input line is a "fallback builtin" provided
for operating systems that do not have common binaries -- such as "ls",
"env", etc, then call the associated subroutine like an ordinary
builtin. If you want all of these commands to be executed within the
shell, you can move this strategy ahead of executable.

=cut

require Psh::Strategy;

use vars qw(@ISA);
@ISA=('Psh::Strategy');

my %fallback_builtin = ('ls'=>1, 'env'=>1 );

sub new { Psh::Strategy::new(@_) }

sub consumes {
	return Psh::Strategy::CONSUME_TOKENS;
}

sub runs_before {
	return qw(executable);
}

sub applies {
	my $fnname = ${$_[2]}[0];
	if( $fallback_builtin{$fnname}) {
		eval 'use Psh::Builtins::Fallback::'.ucfirst($fnname);
		return $fnname;
	}
	return '';
}

sub execute {
	my $self= shift;
	my $line= ${shift()};
	my @words= @{shift()};
	my $command= shift;
	shift @words;
	my $rest= join(' ',@words);

	no strict 'refs';
	$coderef= *{"Psh::Builtins::Fallback::".ucfirst($command)."::bi_$command"};
	return (sub { &{$coderef}($rest,\@words); },[], 0, undef );
}

1;

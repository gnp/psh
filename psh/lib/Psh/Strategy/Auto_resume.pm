package Psh::Strategy::Auto_resume;

=item * C<auto_resume>

If the input line matches the name of a stopped job
then brings that job to the foreground instead of starting
a new program with that name

=cut

require Psh::Strategy;
require Psh::Joblist;

@Psh::Strategy::Auto_resume::ISA=('Psh::Strategy');

sub new { Psh::Strategy::new(@_) }

sub consumes {
	return Psh::Strategy::CONSUME_TOKENS;
}

sub applies {
	my $fnname= ${$_[2]}[0];
    if( my($index, $pid, $call)=
		   Psh::Joblist::find_last_with_name($fnname,1))
    {
		return "auto-resume $call";
	}
    return '';
}

sub execute {
	my $fnname= ${$_[2]}[0];
    my ($index)= Psh::Joblist::find_last_with_name($fnname,1);
    Psh::OS::restart_job(1,$index);
	return (1,undef);
}

sub runs_before {
	return qw(perlscript executable);
}

1;

package Psh::Strategy::Auto_resume;

=item * C<auto_resume>

If the input line matches the name of a stopped job
then brings that job to the foreground instead of starting
a new program with that name

=cut

$Psh::strategy_which{auto_resume}= sub {
	my $fnname= ${$_[1]}[0];
    if( my($index, $pid, $call)=
		   $Psh::joblist->find_last_with_name($fnname,1))
    {
		return "(auto-resume $call)";
	}
    return '';
};

$Psh::strategy_eval{auto_resume}=sub {
	my $fnname= ${$_[1]}[0];
    my ($index)= $Psh::joblist->find_last_with_name($fnname,1);
    Psh::OS::restart_job(1,$index);
    return undef;
};

@always_insert_before= qw( perlscript executable);

1;

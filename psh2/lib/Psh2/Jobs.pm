package Psh2::Jobs;

require POSIX;

my @order= ();
my %list= ();

sub start_job {
    my $array= shift;
    my $fgflag= shift @$array;

    my ($read, $chainout, $chainin);
    my $tmplen= @$array- 1;
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
	    if ($_->[0] == Psh2::Parser::T_REDIRECT and
	        ($_->[1] eq '<&' or $_->[1] eq '>&')) {
		if ($_->[3] eq 'chainin') {
		    $_->[3]= $chainin;
		} elsif ($_->[3] eq 'chainout') {
		    $_->[3]= $chainout;
		}
	    }
	}
	my $termflag= !($i==$tmplen);
	if ($fork) {
	} else {
	    execute($array->[$i]);
	}
    }
}

sub execute {
    my $tmp= shift;
    my ($strategy, $how, $options, $words)= @$tmp;

#    use Data::Dumper;
#    print Dumper($tmp);
    if ($strategy eq 'executable') {
    } elsif ($strategy eq 'builtin') {
	no strict 'refs';
	my $coderef= *{$how.'::execute'};
	&{$coderef}($words);
    }
}

sub delete_job {
}

sub job_exists {
}

sub get_job {
}

sub list_jobs {
}

sub find_job {
}

package Psh2::Unix::Job;

sub new {
    my ($class)= @_;
    my $self= {};
    bless $self, $class;
    return $self;
}

sub resume {
    my $self= shift;
    kill 'CONT', -$self->{pid};
}


1;

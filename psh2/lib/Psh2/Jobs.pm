package Psh2::Jobs;

my @order= ();
my %list= ();

sub start_job {
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

package Psh2::Frontend::Readline;

sub new {
    my ($class, $psh)= @_;
    my $self= {
	       psh => $psh;
	   };
    bless $self, $class;
    return $self;
}

sub init {
    my $self= shift;

    if (-t STDIN) {
	eval { require Term::ReadLine; };
	if ($@) {
	} else {
	    eval { $self->{term}= Term::ReadLine->new('psh2'); };
	    if ($@) {
		# sometimes things take a bit longer strangely...
		sleep 1;
		eval { $self->{term}= Term::ReadLine->new('psh2'); };
		if ($@) {
		    delete $self->{term};
		}
	    }
	    if ( $self->{term} ) {
		
	    }
	}
    }
}

sub getline {
}

1;

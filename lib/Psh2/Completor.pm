package Psh2::Completor;

sub new {
    my ($class, $psh)= @_;
    my $self= {
	       psh => $psh,
	   };
    bless $self, $class;
    return $self;
}

sub complete {
    my ($self, $line, $caret)= @_;

}

1;

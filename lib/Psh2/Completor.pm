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
    $line= substr($line, 0, $caret);
    if ($line=~/(\S+)$/) {
        my $word= $1;
        print STDERR "word is $word\n";
        my @tmp= $self->{psh}->glob("$1*");
        return ($caret-length($word),$caret,\@tmp);
    }
    # return: $from $to (what's replaced by completion)
    # return: [listofcompletions]
}

1;

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
    my $tocomplete;
    my ($prepend,$append)= ('',' ');
    if ($line=~/((?:\S|\\\s)+)$/) {
        $tocomplete= $1;
    }

    $line= substr($line, 0, length($line)-length($tocomplete));

#        print STDERR "word is $word\n";
    my @tmp= $self->{psh}->glob("$tocomplete*");
    $append='/' if @tmp==1 and -d $tmp[0];
    return ($caret-length($tocomplete),$caret,
            $prepend, $append,
            \@tmp);
    # return: $from $to (what's replaced by completion)
    # return: $prepend_characters
    # return: $append_characters
    # return: [listofcompletions]
}

1;

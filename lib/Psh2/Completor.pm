package Psh2::Completor;

sub new {
    my ($class, $psh)= @_;
    my $self= {
	       psh => $psh,
	   };
    bless $self, $class;
    return $self;
}


sub filenames {
    my ($self, $tocomplete)= @_;
    my $returnline='';
    my $newcaret= 0;
    my @tmp= $self->{psh}->glob("$tocomplete*");

    if (@tmp==1) { # interface will be simplified for most cases later on
        my $append='';
        $append='/' if -d $tmp[0];
        $returnline= $self->{line}.$tmp[0].$append;
        $newcaret= length($returnline);
        $returnline.=$self->{rest_of_line};
    }
    if ($tocomplete=~ m:/:) {
        @tmp= map { s:^.*/::; $_ } @tmp;
    }

    return ($returnline,$newcaret, \@tmp);
    # line, newcaret, list
}

sub complete {
    my ($self, $line, $caret)= @_;
    $self->{rest_of_line}= substr($line, $caret);
    $line= substr($line, 0, $caret);
    my $tocomplete;
    if ($line=~/((?:\S|\\\s)+)$/) {
        $tocomplete= $1;
    }

    $self->{line}= substr($line, 0, length($line)-length($tocomplete));

    return $self->filenames($tocomplete);
}

1;

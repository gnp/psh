package Psh2::Completor;

sub new {
    my ($class, $psh)= @_;
    my $self= {
	       psh => $psh,
	   };
    bless $self, $class;
    return $self;
}

sub common_part {
    my ($s1, $s2)= @_;
    return $s1 if $s1 eq $s2;
    my $l1= length($s1); my $l2= length($s2);
    my $l= $l1 < $l2 ? $l1 : $l2;
    while ($l) {
        $s1= substr($s1,0,$l); $s2= substr($s2,0,$l);
        return $s1 if $s1 eq $s2;
        $l--;
    }
    return '';
}

sub filenames {
    my ($self, $tocomplete)= @_;
    my $returnline='';
    my $newcaret= 0;
    my @tmp= $self->{psh}->glob("$tocomplete*");
    my $append=''; my $insert='';

    if (@tmp==1) { # interface will be simplified for most cases later on
        $insert=$tmp[0];
        if (-d $tmp[0]) {
            $append='/';
        } else {
            $append=' ';
        }
    } elsif (@tmp>1) {
        $insert= $tmp[0];
        foreach (@tmp) {
            $insert= common_part($insert, $_);
        }
        if ($min) {
            $returnline= $self->{line}.$min;
            $newcaret= length($returnline);
            $returnline.=$self->{rest_of_line};
        }
    }

    if ($insert) {
        my $prepend='';
        if ($insert=~/[^.a-zA-Z0-9_\/-]/) {
            $prepend='"';
            $append= '"'.$append if $append;
        }
        $returnline= $self->{line}.$prepend.$insert.$append;
        $newcaret= length($returnline);
        $returnline.=$self->{rest_of_line};
    }

    if (@tmp and $tmp[0]=~ m:/:) {
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
    return ('',0,undef) unless $tocomplete;

    $self->{line}= substr($line, 0, length($line)-length($tocomplete));

    return $self->filenames($tocomplete);
}

1;

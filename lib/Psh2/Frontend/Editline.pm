package Psh2::Frontend::Editline;

use strict;
use base 'Psh2::Frontend';

sub new {
    my ($class, $psh)= @_;
    my $self= {
	       psh => $psh,
	   };
    bless $self, $class;
    return $self;
}

sub init {
    my $self= shift;

    if (-t STDIN) {
	eval { require Term::EditLine; };
	if ($@) {
	    print STDERR $@;
	} else {
	    eval { $self->{term}= Term::EditLine->new('psh2'); };
	    if ( $self->{term} ) {
                $self->{term}->add_fun('tabcompl','', sub { tab_completion($self, @_)});
		$self->{term}->parse('bind', '-e');
                $self->{term}->parse('bind', "\\t", 'tabcompl');
	    }
	}
    }
}

sub getline {
    my $self= shift;
    my $line;
    eval {
	$self->{term}->set_prompt('> ');
	$line= $self->{term}->gets();
	if (defined $line) {
	    $self->{term}->history_enter($line);
	}
    };
    if ($@) {
	# TODO: Error handling
    }

    return undef unless defined $line;
    chomp $line;
    return $line;
}

sub tab_completion {
    my $self= shift;
    my ($buffer, $caret, $length)= $self->{term}->line();
    $buffer= substr($buffer,0,$length); # JIC
    my ($pos,completions= $self->{psh}->completor->complete($buffer,$caret);

#    $self->{term}->insertstr("Tab completion dummy");
    return Term::EditLine::CC_REFRESH();
}

1;

package Psh2::Frontend::Readline;

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
        $ENV{PERL_RL}='Gnu o=0';
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
                    die $@;
		}
	    }
	    if ( $self->{term} ) {
                my $attribs= $self->{term}->Attribs;
                $self->{term}->add_defun('complete2', sub { tab_completion($self)} );
                $self->{term}->parse_and_bind(qq["\t":complete2]);
                $self->{term}->parse_and_bind(qq["\\M-\e":complete2]);
                $self->{term}->parse_and_bind(qq["\\C-i":complete2]);
                $attribs->{completion_function}= sub { tab_completion2($self)};
	    }
	}
    }
}

sub getline {
    my $self= shift;
    my $line;
    eval {
	$line= $self->{term}->readline('> ');
    };
    if ($@) {
	# TODO: Error handling
    }

    return undef unless defined $line;
    chomp $line;
    return $line;
}

# we override tab completion itself to have more control
sub tab_completion {
    my $self= shift;
    my $attribs= $self->{term}->Attribs;
    my $buffer= $attribs->{line_buffer};
    my $caret= $attribs->{point};
    my ($from, $to, $pre, $app, $list)= $self->{psh}->completor->complete($buffer,$caret);
    if ($list and @$list) {
        if (@$list>1) {
            print "\n";
            $self->print_list(@$list);
            $self->{term}->on_new_line();
        } else {
            my $tmp= $pre.$list->[0].$app;
            substr($buffer,$from,$to)= $tmp;
            $attribs->{line_buffer}= $buffer;
            $attribs->{point}= $from+length($tmp);
        }
    }
    $self->{term}->redisplay();
    '';
}

# for the other completion functions like insert-completions
sub tab_completion2 {
    return ();
}

1;

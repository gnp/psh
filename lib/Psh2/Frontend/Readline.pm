package Psh2::Frontend::Readline;

use strict;

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

sub print {
    my $self= shift;
    my $where= shift;
    if ($where==0) {
	CORE::print STDOUT @_;
    } else {
	CORE::print STDERR @_;
    }
}

sub print_list {
    my $self= shift;
    my @list= @_;
    return unless @list;
    my ($lines, $columns, $mark, $index);

    ## find width of widest entry
    my $maxwidth = 0;
    my $screen_width=$ENV{COLUMNS}||78;

    grep(length > $maxwidth && ($maxwidth = length), @list);
    $maxwidth++;
    $columns = $maxwidth >= $screen_width?1:int($screen_width / $maxwidth);

    $maxwidth += int(($screen_width % $maxwidth) / $columns);

    $lines = int((@list + $columns - 1) / $columns);
    $columns-- while ((($lines * $columns) - @list + 1) > $lines);

    $mark = $#list - $lines;
    for (my $l = 0; $l < $lines; $l++) {
        for ($index = $l; $index <= $mark; $index += $lines) {
	    my $tmp= my $item= $list[$index];
	    $tmp=~ s/\001(.*?)\002//g;
	    $item=~s/\001//g;
	    $item=~s/\002//g;
	    my $diff= length($item)-length($tmp);
	    my $dispsize= $maxwidth+$diff;
            printf("%-${dispsize}s", $item);
        }
	if ($index<=$#list) {
	    my $item= $list[$index];
	    $item=~s/\001//g; $item=~s/\002//g;
	    print $item;
	}
        print "\n";
    }
}

sub prompt {
    my ($self, $valid, $promptstring)= @_;
    $valid= "^[$valid]\$";
    my $line='';

    do {
	print $promptstring.' ';
	$line=<STDIN>;
    } while (!$line || lc($line) !~ $valid);
    chomp $line;
    return lc($line);
}

# we override tab completion itself to have more control
sub tab_completion {
    my $self= shift;
    my $attribs= $self->{term}->Attribs;
    my $buffer= $attribs->{line_buffer};
    my $caret= $attribs->{point};
    my ($from, $to, $list)= $self->{psh}->completor->complete($buffer,$caret);
    if ($list and @$list and @$list>1) {
        $self->print_list(@$list);
    }
    $self->{term}->redisplay();
    '';
}

# for the other completion functions like insert-completions
sub tab_completion2 {
    return ();
}

1;

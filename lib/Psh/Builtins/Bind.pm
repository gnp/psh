package Psh::Builtins::Bind;

use Psh::Util ':all';

=pod

=item * C<bind [-m keymap] [-lvd] [-q name]>

=item * C<bind [-m keymap] -f filename>

=item * C<bind [-m keymap] keyseq:function-name>

  

Display current readline key and function bindings,
or bind a key sequence to a readline function or
macro. The binding syntax accepted is identical to
that of .inputrc, but each binding must be passed
as a  separate  argument;  e.g.,  '"\C-x\C-r":
re-read-init-file'. Options, if supplied, have the
following meanings:

=over 8

=item -m keymap

Use keymap as the keymap to be affected by
the subsequent bindings. Acceptable keymap
names are emacs, emacs-standard, emacs-meta,
emacs-ctlx, vi, vi-move, vi-command, and vi-
insert. vi is equivalent to vi-command;
emacs is equivalent to emacs-standard.

=item -l

List the names of all readline functions

=item -v

List current function names and bindings

=item -d

Dump function names and bindings in such a
way that they can be re-read

=item -f filename

Read key bindings from filename

=item -q function

Query about which keys invoke the named

=back

=cut

#
# > TODO: How can we print out the current bindings in an
# > ReadLine-implementation-independent way? We should allow rebinding
# > of keys if Readline interface allows it, etc.
#
# This implementation supports GNU fully.  It also kind of supports Perl.
# All others it will refuse to work with.
#
# > Info:
# > Bind a key: GNU: bind_key Perl: bind
#
# I implemented GNU using parse_and_bind as it gives a result more
# consistant with what bash does.
#
# > Other interesting stuff
# > Perl: set(EditingMode) - vi or emacs keybindings
#
# I impelemented this as a "keymap".  (I notice that internally this
# is what the EditingMode's are refered to as anyway.)
#
# > Perl: set(TcshCompleteMode) - tcsh menu completion mode
# > GNU: lots and lots...
#

sub bi_bind {
    my $status = 0;
    if (defined($Psh::term) and $Psh::term->can('add_defun')) {
        my $args = pop;
        while (my $command = shift(@$args)) {
            if ($command eq '-l') {
                for my $function (sort($Psh::term->get_all_function_names)) {
                    print_out("$function\n");
                }
            } elsif ($command eq '-m') { # Set keymap
                my $keymap_name = shift(@$args);
                my $map = $Psh::term->get_keymap_by_name($keymap_name);
                if (defined($map)) {
                    $Psh::term->set_keymap($map);
                } else {
                    print_out(qq{bind: `$keymap_name': illegal keymap name\n});
                    $status = 1;
                }
            } elsif ($command eq '-v') { # Show values
                for my $function (sort($Psh::term->get_all_function_names)) {
                    print_out("$function ");
                    my(@keys) = $Psh::term->invoking_keyseqs($function);
                    if (@keys) {
                        print_out(qq{can be found on "},join('", "',@keys),qq{".\n});
                    } else {
                        print_out("is not bound to any keys\n");
                    }
                }
            } elsif ($command eq '-d') { # Dump values
                for my $function (sort($Psh::term->get_all_function_names)) {
                    my(@keys) = $Psh::term->invoking_keyseqs($function);
                    if (@keys) {
                        foreach (@keys) {
                            print_out(qq{"$_": $function\n});
                        }
                    } else {
                        print_out("# $function (not bound)\n");
                    }
                }
            } elsif ($command eq '-f') { # Read file
                my $file = shift(@$args);
                $Psh::term->read_init_file($file);
                if ($!) {
                    print_out("bind: cannot read $file: $!\n");
                    $status = 1;
                }
            } elsif ($command eq '-q') { # Query a single function
                my $function = shift(@$args);
                print_out("$function ");
                my(@keys) = $Psh::term->invoking_keyseqs($function);
                if (@keys) {
                    print_out(qq{can be found on "},join('", "',@keys),qq{".\n});
                } else {
                    print_out("is not bound to any keys\n");
                }
            } elsif ($command =~ /:/) {
                unless ($command =~ /:./) {
                    # This let's the user do things like this:
                    #  bind "\en": history-search-forward "\ep": history-search backward
                    $command .= shift(@$args);
                }
                ### This is to make my bash-happy bind statements work.
                ### This is undoubtably dumb.  If someone could tell me
                ### how to make readline work with M- as meta, I'd be
                ### enternally grateful.
                $command =~ s/^M-(.)/"\\e$1"/g;
                ###
                $Psh::term->parse_and_bind($command);
            } else {
                # print help (unknown option)
                print_out("bind: illegal option: $command\n");
                print_out("usage: bind [-lvd] [-m keymap] [-f filename] [-q name] [keyseq:readline_func]\n");
                $status = 1;
                last;
            }
        }
    } elsif (defined($Psh::term) and $Psh::term->can('bind')) {
        # Term::ReadLine::Perl
        my $args = pop;
        while (my $command = shift(@$args)) {
            if ($command eq '-l') {
                print_out("bind: -l option currently not supported by ".ref($Psh::term)."\n");
                $status = 1;
                last;
            } elsif ($command eq '-m') { # Set keymap
                my $keymap_name = shift(@$args);
                my $map = ($keymap_name =~ /^(emacs|vi)$/i)?$1:undef;
                if (defined($map)) {
                    $Psh::term->set('EditingMode',$map);
                } else {
                    print_out(qq{bind: `$keymap_name': illegal keymap name\n});
                    $status = 1;
                }
            } elsif ($command eq '-v') { # Show values
                print_out("bind: -v option currently not supported by ".ref($Psh::term)."\n");
                $status = 1;
                last;
            } elsif ($command eq '-d') { # Dump values
                print_out("bind: -d option currently not supported by ".ref($Psh::term)."\n");
                $status = 1;
                last;
            } elsif ($command eq '-f') { # Read file
                print_out("bind: -f option currently not supported by ".ref($Psh::term)."\n");
                $status = 1;
                last;
            } elsif ($command eq '-q') { # Query a single function
                print_out("bind: -q option currently not supported by ".ref($Psh::term)."\n");
                $status = 1;
                last;
            } elsif ($command =~ /:/) {
                unless ($command =~ /:./) {
                    # This let's the user do things like this:
                    #  bind "\en": history-search-forward "\ep": history-search backward
                    $command .= shift(@$args);
                }
                my($keys,$function) = split(/\s*:\s*/,$command,2);
                $keys =~ s/^"(.*)"$/$1/ or
                $keys =~ s/^'(.*)'$/$1/;
                $Psh::term->bind($keys,$function);
            } else {
                # print help (unknown option)
                print_out("bind: illegal option: $command\n");
                print_out("usage: bind [-lvd] [-m keymap] [-f filename] [-q name] [keyseq:readline_func]\n");
                $status = 1;
                last;
            }
        }
    } elsif (defined($Psh::term) and ref($Psh::term)) {
        print_out("bind requires a more capable readline then ".ref($Psh::term)."\n");
        $status = 1;
    } else {
        print_out("bind: No effect in non-interactive terminal\n");
        $status = 1;
    }
    
    return $status;
}

1;

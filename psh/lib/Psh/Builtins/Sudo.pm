package Psh::Builtins::Sudo;

use strict;

=item * C<sudo>

Wrapper around the sudo program which sets $ENV{PATH},
expands command aliases and defers shell globbing
until sudo runs.

=cut

sub bi_sudo {

    # Fix up $ENV{PATH} for root commands:
    #     Replace with sudo_replace_path (if set)
    #     Add any elements in sudo_add_path (if set)

    my $path_sep = Psh::Options::get_option('array_exports')->{'path'};

    my $path         = Psh::Options::get_option('path');
    my $add_path     = Psh::Options::get_option('sudo_add_path');
    my $replace_path = Psh::Options::get_option('sudo_replace_path');

    @$path = @$replace_path if $replace_path and ref $replace_path eq 'ARRAY';
    push @$path, @$add_path if $add_path and ref $add_path eq 'ARRAY';

    local $ENV{'PATH'} = join $path_sep, @$path;


    # We run sudo through a shell, in order to defer shell expansions until
    # we are running as root.  We could use any shell here (including psh)
    # but psh takes quite a long time to start up, so the default is /bin/sh

    my $sudo_shell   = Psh::Options::get_option('sudo_shell');
    $sudo_shell    ||= '/bin/sh -c';
    my @sudo_shell   = split /\s+/, $sudo_shell;


    # Parse the command line to expand the command (e.g. aliases)

    my @result = Psh::Parser::parse_line($_[0], 'executable');

    my $cmd = $result[0][2][4];

    # Expand the 'sudo' command itself (in case it is also an alias)

    @result = Psh::Parser::parse_line('sudo', 'executable');

    # We want the sudo command as an array of words (for passing to system)
    my @sudo_cmd = split /\s+/, $result[0][2][4];

    system(@sudo_cmd, @sudo_shell, $cmd);
}

1;


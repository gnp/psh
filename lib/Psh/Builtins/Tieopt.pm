package Psh::Builtins::Tieopt;

require Psh;
require Psh::Util;
require Psh::Support::TiedOption;
require Psh::Options;

=item * C<tieopt NAME $VAR>

=item * C<tieopt NAME @VAR>

=item * C<tieopt NAME %VAR>

Ties the option named NAME to the global variable $VAR, @VAR or %VAR

=item * C<tieopt NAME>

Ties the option named NAME to the global variable named $NAME, @NAME, or %NAME, depending on the option's type.

=item * C<tieopt -u $VAR>

Unties the global variable named $VAR
Note that you can simply use perl's built-in C<untie $VAR>

=cut

sub bi_tieopt {
    my $line = shift;
    my @words = @{shift()};

    my ($untie, $name, $var, $actual_type, $requested_type);

    my %var_types = (
        '$' => 'SCALAR',
        '@' => 'ARRAY',
        '%' => 'HASH',
    );

    # untie NAME
    # untie $VAR
    if ($words[0] =~ /^-u$/i) {
        $untie = 1;

        $var  = $words[1];
        if ($var =~ /^(\$|\@|\%)/) {
            $requested_type = $var_types{$1};
        }
        $var  =~ s/\W//g;
        $name = $var;

    }

    # tieopt NAME
    # tieopt $VAR
    elsif (@words == 1) {
        $name = $words[0];

        if ($name =~ /^(\$|\@|\%)/) {
            $requested_type = $var_types{$1};
        }
        $name =~ s/\W//g;

        $var = $name;
    }
    # tieopt NAME $VAR
    elsif (@words == 2) {
        ($name, $var) = @words;

        if ($var =~ /^(\$|\@|\%)/) {
            $requested_type = $var_types{$1};
        }
        $name =~ s/\W//g;
        $var  =~ s/\W//g;
    }
    else {
        return;
    }


    $curr_val = Psh::Options::get_option($name);

    $actual_type = ref $curr_val;

    if (defined $curr_val) {
        if (ref $curr_val) {
            if (ref $curr_val eq 'ARRAY' and @$curr_val) {
                $actual_type = 'ARRAY';
            }
            if (ref $curr_val eq 'HASH' and keys %curr_val) {
                $actual_type = 'HASH';
            }
        }
        else {
            if ($curr_val) {
                $actual_type = 'SCALAR';
            }
        }
    }

    $requested_type ||= $actual_type || 'SCALAR';

    if ($untie) {
        no strict 'refs';
        if ($requested_type eq 'SCALAR') {
            untie ${"main\:\:$name"};
        }
        if ($requested_type eq 'ARRAY') {

            untie @{"main\:\:$name"};
        }
        if ($requested_type eq 'HASH') {
            untie %{"main\:\:$name"};
        }
    }
    else {
        if ($actual_type and $actual_type ne $requested_type) {
            if ($requested_type eq 'ARRAY') {
                Psh::Util::print_error_i18n('bi_tieopt_badtype_array', $name);
            }
            elsif ($requested_type eq 'HASH') {
                Psh::Util::print_error_i18n('bi_tieopt_badtype_hash', $name);
            }
            else {
                Psh::Util::print_error_i18n('bi_tieopt_badtype_scalar', $name);
            }
            return;
        }
        # print STDERR "tying option: $name to \${main\:\:$var}\n" if $requested_type eq 'SCALAR';
        # print STDERR "tying option: $name to \@{main\:\:$var}\n" if $requested_type eq 'ARRAY';
        # print STDERR "tying option: $name to \%{main\:\:$var}\n" if $requested_type eq 'HASH';

        {

            # Tie the $name to $var
            no strict 'refs';
            if ($requested_type eq 'SCALAR') {
                Psh::Options::set_option($name, '') unless $actual_type;
                tie ${"main\:\:$var"}, 'Psh::Support::TiedOption::Scalar', $name;
            }
            if ($requested_type eq 'ARRAY') {
                Psh::Options::set_option($name, []) unless $actual_type;
                tie @{"main\:\:$var"}, 'Psh::Support::TiedOption::Array', $name;

            }
            if ($requested_type eq 'HASH') {
                Psh::Options::set_option($name, {}) unless $actual_type;
                tie %{"main\:\:$var"}, 'Psh::Support::TiedOption::Hash',   $name;
            }
        }
    }
}

1;

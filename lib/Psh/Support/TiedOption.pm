
use strict;

require Psh;
require Psh::Options;

package Psh::Support::TiedOption;
package Psh::Support::TiedOption::Scalar;

sub TIESCALAR {
    my ($class, $optname) = @_;
    return bless \$optname, $class;
}
sub FETCH {
    my $optname = shift;
    my $val = Psh::Options::get_option($$optname);
    if (ref $val) {
        Psh::Util::print_error_i18n('bi_tieopt_fetch_badtype_scalar', $$optname);
        return;
    }
    return $val;
}
sub STORE {
    my ($optname, $newval) = @_;
    my $val = Psh::Options::get_option($$optname);
    if (ref $val) {
        Psh::Util::print_error_i18n('bi_tieopt_fetch_badtype_scalar', $$optname);
        return;
    }
    Psh::Options::set_option($$optname, $newval);
}

package Psh::Support::TiedOption::Array;

sub TIEARRAY {
    my ($class, $optname) = @_;
    return bless \$optname, $class;
}
sub FETCH {
    my ($optname, $index) = @_;
    my $val = Psh::Options::get_option($$optname);
    unless (ref $val eq 'ARRAY') {
        Psh::Util::print_error_i18n('bi_tieopt_fetch_badtype_array', $$optname);
        return;
    }
    return $val->[$index];
}
sub STORE {
    my ($optname, $index, $newval) = @_;
    my $array = scalar Psh::Options::get_option($$optname);

    unless (ref $array eq 'ARRAY') {
        Psh::Util::print_error_i18n('bi_tieopt_fetch_badtype_array', $$optname);
        return;
    }
    $array->[$index] = $newval;
    Psh::Options::set_option($$optname, $array);
}
sub FETCHSIZE {
    my ($optname) = @_;
    my $val = Psh::Options::get_option($$optname);
    unless (ref $val eq 'ARRAY') {
        Psh::Util::print_error_i18n('bi_tieopt_fetch_badtype_array', $$optname);
        return;
    }
    return scalar @$val;
}
sub CLEAR {
    my ($optname) = @_;
    my $val = Psh::Options::get_option($$optname);
    unless (ref $val eq 'ARRAY') {
        Psh::Util::print_error_i18n('bi_tieopt_fetch_badtype_array', $$optname);
        return;
    }
    Psh::Options::set_option($$optname, []);
}

sub EXTEND {
}


package Psh::Support::TiedOption::Hash;

sub TIEHASH {
    my ($class, $optname) = @_;
    return bless \$optname, $class;
}
sub FETCH {
    my ($optname, $key) = @_;
    my $val = Psh::Options::get_option($$optname);
    unless (ref $val eq 'HASH') {
        Psh::Util::print_error_i18n('bi_tieopt_fetch_badtype_hash', $$optname);
        return;
    }
    return $val->{$key};
}
sub STORE {
    my ($optname, $key, $newval) = @_;
    my $hash = scalar Psh::Options::get_option($$optname);
    unless (ref $hash eq 'HASH') {
        Psh::Util::print_error_i18n('bi_tieopt_fetch_badtype_hash', $$optname);
        return;
    }
    $hash->{$key} = $newval;
    Psh::Options::set_option($$optname, $hash);
}
sub EXISTS {
    my ($optname, $key) = @_;
    my $val = Psh::Options::get_option($$optname);
    unless (ref $val eq 'HASH') {
        Psh::Util::print_error_i18n('bi_tieopt_fetch_badtype_hash', $$optname);
        return;
    }
    return exists $val->{$key};
}
sub DELETE {
    my ($optname, $key) = @_;
    my $val = Psh::Options::get_option($$optname);
    unless (ref $val eq 'HASH') {
        Psh::Util::print_error_i18n('bi_tieopt_fetch_badtype_hash', $$optname);
        return;
    }
    return delete $val->{$key};
}
sub CLEAR {
    my ($optname) = @_;
    my $val = Psh::Options::get_option($$optname);
    unless (ref $val eq 'HASH') {
        Psh::Util::print_error_i18n('bi_tieopt_fetch_badtype_hash', $$optname);
        return;
    }
    Psh::Options::set_option($$optname, {});
}
sub FIRSTKEY {
    my ($optname) = @_;
    my $val = Psh::Options::get_option($$optname);
    unless (ref $val eq 'HASH') {
        Psh::Util::print_error_i18n('bi_tieopt_fetch_badtype_hash', $$optname);
        return;
    }
    # Reset keys iterator
    my $reset_keys = keys %$val;
    return each %$val;
}
sub NEXTKEY {
    my ($optname) = @_;
    my $val = Psh::Options::get_option($$optname);
    unless (ref $val eq 'HASH') {
        Psh::Util::print_error_i18n('bi_tieopt_fetch_badtype_hash', $$optname);
        return;
    }
    return each %$val;
}

1;


package Psh2::Unix;

sub path_separator { ':' }
sub file_separator { '/' }
sub getcwd {
    my $cwd;
    chomp( $cwd = `pwd`);
    return $cwd;
}

# File::Spec

sub canonpath {
    my ($path) = @_;
    $path =~ s|/+|/|g unless($^O eq 'cygwin');     # xx////xx  -> xx/xx
    $path =~ s|(/\.)+/|/|g;                        # xx/././xx -> xx/xx
    $path =~ s|^(\./)+||s unless $path eq "./";    # ./xx      -> xx
    $path =~ s|^/(\.\./)+|/|s;                     # /../../xx -> xx
    $path =~ s|/\Z(?!\n)|| unless $path eq "/";          # xx/       -> xx
    return $path;
}

sub catfile {
    my $file = pop @_;
    return $file unless @_;
    my $dir = catdir(@_);
    $dir .= "/" unless substr($dir,-1) eq "/";
    return $dir.$file;
}

sub catdir {
    my @args = @_;
    foreach (@args) {
        # append a slash to each argument unless it has one there
        $_ .= "/" if $_ eq '' || substr($_,-1) ne "/";
    }
    return canonpath(join('', @args));
}

sub file_name_is_absolute {
	my $file= shift;
	return scalar($file =~ m:^/:s);
}

sub rootdir {
	'/';
}

sub splitdir {
    my ($directories) = @_ ;

    if ( $directories !~ m|/\Z(?!\n)| ) {
        return split( m|/|, $directories );
    }
    else {
        my( @directories )= split( m|/|, "${directories}dummy" ) ;
        $directories[ $#directories ]= '' ;
        return @directories ;
    }
}

sub rel2abs {
    my ($path,$base ) = @_;

    # Clean up $path
    if ( !file_name_is_absolute( $path ) ) {
        # Figure out the effective $base and clean it up.
        if ( !defined $base or $base eq '' ) {
            $base = Psh2::getcwd() ;
        }
        elsif ( !file_name_is_absolute( $base ) ) {
            $base = rel2abs( $base ) ;
        }
        else {
            $base = canonpath( $base ) ;
        }

        # Glom them together
        $path = catdir( $base, $path ) ;
    }
    return canonpath( $path ) ;
}

1;

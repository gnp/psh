package Psh::Builtins::Fallback;

# void bi_ls
# like the Unix binary but without options
sub bi_ls
{
	my $pattern= shift || '*';
	my $ps= $Psh::OS::FILE_SEPARATOR;
	$pattern.=$ps.'*' if( $pattern !~ /\*/ &&
						  -d Psh::Util::abs_path($pattern));
	my @files= map { 
		    return $1 if( m:\Q$ps\E([^\Q$ps\E]+)$:); $_
		} Psh::OS::glob($pattern);
	Psh::Util::print_list(@files);
	return undef;
}

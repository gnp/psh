package Psh::Support::Env;

use vars qw(%array_exports);

%array_exports=('PATH'=>$PS,'CLASSPATH'=>$PS,'LD_LIBRARY_PATH'=>$PS,
				'FIGNORE'=>$PS,'CDPATH'=>$PS,'LS_COLORS'=>':');

#
# string do_setenv(string command)
#
# command is of the form "VAR VALUE" or "VAR = VALUE" or "VAR"; sets
# $ENV{VAR} to "VALUE" in the first two cases, or to "$VAR" in the
# third case unless $VAR is undefined. Used by the setenv and export
# builtins. Returns VAR (which is a string with no $).

sub do_setenv
{
	my $arg = shift;
	if( $arg=~ /^\s*(\w+)(\s+|\s*=\s*)(.+)/ ) {
		my $var= $1;
		my $value= $3;
		if( $value=~ /^\'(.*)\'\s*$/ ) {
			# If single quotes were used, do not interpret
			# variables
			$ENV{$var}=$1;
		} else {
			$var =~ s/^\$//;
			if ($value=~ /^\"(.*)\"/) {
				$value=$1;
			}
			# Use eval so that variables may appear on RHS
			# ($value); use protected_eval so that lexicals
			# in this file don't shadow package variables
			Psh::PerlEval::protected_eval("\$ENV{$var}=\"$value\"", 'do_setenv');
		}
		return $var;
	} elsif( $arg=~ /(\w+)/ ) {
		my $var= $1;
		$var =~ s/^\$//;
		Psh::PerlEval::protected_eval("\$ENV{$var}=\$$var if defined(\$$var);",
			       'do_setenv');
		return $var;
	}
	return '';
}


1;

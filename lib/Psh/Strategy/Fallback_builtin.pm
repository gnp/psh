package Psh::Strategy::Fallback_builtin;

=item * C<fallback_builtin>

If the first word of the input line is a "fallback builtin" provided
for operating systems that do not have common binaries -- such as "ls",
"env", etc, then call the associated subroutine like an ordinary
builtin. If you want all of these commands to be executed within the
shell, you can move this strategy ahead of executable.

=cut

%fallback_builtin = ('ls'=>1, 'env'=>1 );



$Psh::strategy_which{fallback_builtin}= sub {
		my $fnname = ${$_[1]}[0];
		
		if( $Psh::fallback_builtin{$fnname}) {
			eval 'use Psh::Builtins::Fallback::'.ucfirst($fnname);
            return "(fallback built in $fnname)";
        }
		return '';
};


$Psh::strategy_eval{fallback_builtin}= sub {
		my $line= ${shift()};
        my @words= @{shift()};
        my $command= shift @words;
        my $rest= join(' ',@words);
        {
	        no strict 'refs';
	        $coderef= *{"Psh::Builtins::Fallback::".ucfirst($command)."::bi_$command"};
            return (sub { &{$coderef}($rest,\@words); },[], 0, undef );
        }
};


1;

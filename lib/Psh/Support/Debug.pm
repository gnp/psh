package Psh::Support::Debug;

my %token_types= ( 0=> 'END', 1=>'WORD:',2=>'PIPE',
				   3=>'REDIRECT',4=>'BACKGROUND' );

sub explain_tokens {
	my $tokens= shift;
	my @result=();
	my @tokens= @$tokens;
	foreach my $tok (@tokens) {
		if (ref $tok eq 'ARRAY') {
			my @tok=@$tok;
			my $type= shift @tok;
			if ($type==0) {
				push @result,"\n";
			} else {
				$type= $token_types{$type} if $token_types{$type};
				push @result, join('',$type,@tok,' ');
			}
		}
	}
	return join('',@result);
}

1;

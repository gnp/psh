
use Psh::Locale::Base;

print "1..2\n";

&Psh::Locale::Base::init();

if( $#psh::mon==11) { print "ok\n"; }
else { print "not ok\n"; }

if( $#psh::wday==6) { print "ok\n"; }
else { print "not ok\n"; }



use Psh::Locale::Base;

print "1..2\n";

&Psh::Locale::Base::init();

if( $#Psh::mon==11) { print "ok\n"; }
else { print "not ok\n"; }

if( $#Psh::wday==6) { print "ok\n"; }
else { print "not ok\n"; }

use Psh::Locale::Default;
use Psh::Locale::French;
use Psh::Locale::German;
use Psh::Locale::Italian;
use Psh::Locale::Portuguese;
use Psh::Locale::Spanish;

use Psh::Locale::Base;

print "1..2\n";

while (<__DATA__>) {
	eval ($_);
	print "$@\n" if $@;
}

&Psh::Locale::Base::init();

if ($#Psh::mon == 11) {
	print "month count ok\n";
} else {
	print "month count not ok\n";
}

if ($#Psh::wday == 6) {
	print "day of week count ok\n";
} else {
	print "day of week count not ok\n";
}

__DATA__
use Psh::Locale::Default;
use Psh::Locale::French;
use Psh::Locale::German;
use Psh::Locale::Italian;
use Psh::Locale::Portuguese;
use Psh::Locale::Spanish;

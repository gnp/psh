use Psh::Locale::Base;

print "1..2\n";

while (<DATA>) {
	eval ($_);
	print "$@\n" if $@;
}

&Psh::Locale::Base::init();

if ($#Psh::mon == 11) {
	print "month count ok\n";
	print "ok 1\n";
} else {
	print "month count not ok\n";
	print "not ok 1\n";
}

if ($#Psh::wday == 6) {
	print "day of week count ok\n";
	print "ok 2\n";
} else {
	print "day of week count not ok\n";
	print "not ok 2\n";
}

__DATA__
use Psh::Locale::Default;
use Psh::Locale::French;
use Psh::Locale::German;
use Psh::Locale::Italian;
use Psh::Locale::Portuguese;
use Psh::Locale::Spanish;

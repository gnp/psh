package Psh::Locale;

#
# Here is the list of ISO-639:1988 language codes. Obtained from
# http://www.uk.adlibsoft.com/iso/iso639.html on 1999-12-26.
#
#  aa Afar
#  ab Abkhazian
#  af Afrikaans
#  am Amharic
#  ar Arabic
#  as Assamese
#  ay Aymara
#  az Azerbaijani
#
#  ba Bashkir
#  be Byelorussian
#  bg Bulgarian
#  bh Bihari
#  bi Bislama
#  bn Bengali; Bangla
#  bo Tibetan
#  br Breton
#
#  ca Catalan
#  co Corsican
#  cs Czech
#  cy Welsh
#
#  da Danish
#  de German
#  dz Bhutani
#
#  el Greek
#  en English
#  eo Esperanto
#  es Spanish
#  et Estonian
#  eu Basque
#
#  fa Persian
#  fi Finnish
#  fj Fiji
#  fo Faeroese
#  fr French
#  fy Frisian
#
#  ga Irish
#  gd Scots Gaelic
#  gl Galician
#  gn Guarani
#  gu Gujarati
#
#  ha Hausa
#  hi Hindi
#  hr Croatian
#  hu Hungarian
#  hy Armenian
#
#  ia Interlingua
#  ie Interlingue
#  ik Inupiak
#  in Indonesian
#  is Icelandic
#  it Italian
#  iw Hebrew
#
#  ja Japanese
#  ji Yiddish
#  jw Javanese
#
#  ka Georgian
#  kk Kazakh
#  kl Greenlandic
#  km Cambodian
#  kn Kannada
#  ko Korean
#  ks Kashmiri
#  ku Kurdish
#  ky Kirghiz
#
#  la Latin
#  ln Lingala
#  lo Laothian
#  lt Lithuanian
#  lv Latvian, Lettish
#
#  mg Malagasy
#  mi Maori
#  mk Macedonian
#  ml Malayalam
#  mn Mongolian
#  mo Moldavian
#  mr Marathi
#  ms Malay
#  mt Maltese
#  my Burmese
#
#  na Nauru
#  ne Nepali
#  nl Dutch
#  no Norwegian
#
#  oc Occitan
#  om (Afan) Oromo
#  or Oriya
#
#  pa Punjabi
#  pl Polish
#  ps Pashto, Pushto
#  pt Portuguese
#
#  qu Quechua
#
#  rm Rhaeto-Romance
#  rn Kirundi
#  ro Romanian
#  ru Russian
#  rw Kinyarwanda
#
#  sa Sanskrit
#  sd Sindhi
#  sg Sangro
#  sh Serbo-Croatian
#  si Singhalese
#  sk Slovak
#  sl Slovenian
#  sm Samoan
#  sn Shona
#  so Somali
#  sq Albanian
#  sr Serbian
#  ss Siswati
#  st Sesotho
#  su Sundanese
#  sv Swedish
#  sw Swahili
#
#  ta Tamil
#  te Tegulu
#  tg Tajik
#  th Thai
#  ti Tigrinya
#  tk Turkmen
#  tl Tagalog
#  tn Setswana
#  to Tonga
#  tr Turkish
#  ts Tsonga
#  tt Tatar
#  tw Twi
#
#  uk Ukrainian
#  ur Urdu
#  uz Uzbek
#
#  vi Vietnamese
#  vo Volapuk
#
#  wo Wolof
#
#  xh Xhosa
#
#  yo Yoruba
#
#  zh Chinese
#  zu Zulu
#

my (@mon,@wday);
my $locale_loaded;
my $special_locale=0;

sub load_locale {
	return if $locale_loaded;
	eval "require Psh::Locale::Default";

	my $lang= $ENV{LANG};
	# Now try to use a locale module depending on LANG
	if( $lang and $lang ne "C" and $lang ne "POSIX") {
		$lang=lc($lang);

		my %alias_table= (
				  "de_de"     => "German",
				  "deutsch"   => "German",
				  "de"        => "German",

				  "es"        => "Spanish",
				  "español"   => "Spanish",
				  "espanol"   => "Spanish",
				  "es_es"     => "Spanish",

				  "fr"        => "French",
				  "français"  => "French",
				  "francais"  => "French",
				  "fr_fr"     => "French",

				  "it"        => "Italian",
				  "italiano"  => "Italian",
				  "it_it"     => "Italian",

				  "pt"        => "Portuguese",
				  "português" => "Portuguese",
				  "portugues" => "Portuguese",
				  "pt_pt"     => "Portuguese",
						 );

		$lang=$alias_table{$lang} if( exists $alias_table{$lang});
	    $lang=ucfirst($lang);
		eval "use Psh::Locale::$lang";
		#
		# We are reading the locale data simply as perl modules
		# A better way would be to maybe use Locale::PGetText
		# but that would again increase the requirements for
		# psh unnecessarily
		$special_locale=1;
	}
	$locale_loaded=1;
}


# You can call the following a hack - we call
# strftime to calculate dates to get the locale dependent
# names - if anybody knows a better method to access
# the locales installed on the system, feel free to change it
sub months {
	if (@_) {
		@mon=@_;
	} else {
		unless (@mon) {
			if ($speciallocale) {
				require POSIX;
				for( my $i=0; $i<12; $i++) {
					push( @mon, POSIX::strftime("%b",0,0,0,1,$i,99));
				}
			} else {
				@mon= qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
			}
		}
	}
	return @mon;
}

sub weekdays {
	if (@_) {
		@wday=@_;
	} else {
		unless (@wday) {
			if ($speciallocale) {
				require POSIX;
				for( my $i=0; $i<7; $i++) {
					push( @wday, POSIX::strftime("%a",0,0,0,19+$i,11,99,$i));
				}
			} else {
				@wday=qw(Sun Mon Tue Wed Thu Fri Sat);
			}
		}
	}
	return @wday;
}

sub get_text {
	my $key= shift;
	load_locale();
	return $Psh::text{$key};
}

sub set_text {
	my $key= shift;
	my $val= shift;
	load_locale();
	$Psh::text{$key}= $val;
}


1;
__END__

=head1 NAME

Psh::Locale - containing base code for I18N

=head1 SYNOPSIS


=head1 DESCRIPTION

   Psh::Locale::init();

Initializes locale support

   @tmp= Psh::Locale::months();

Returns an array of locale-dependant month names

   @tmp= Psh::Locale::weekdays();

Returns an array of locale-dependant weekday names

   Psh::Locale::months(qw(Jan Feb ...));

Sets the month names

   Psh::Locale::weekdays(qw(Jan Feb ...));

Sets the weekday names

   Psh::Locale::get_text($name)

Returns the named text from the current locale

   Psh::Locale::set_text($name,$value)

Sets the text

=head1 AUTHOR

Markus Peter, warp@spin.de

=cut

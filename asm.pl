#!/usr/bin/perl

use 5.34.0;
use warnings;
use feature qw(signatures);
no warnings qw(experimental::signatures);

use YAML::XS;
use Data::Dump;

my $ilist = YAML::XS::LoadFile('instructions.yaml');
$ilist = { reverse %$ilist };
#dd $ilist;

my $reg8 = qr/([ABHL])/;
my $val8 = qr/('.'|0x[[:xdigit:]]{2}|25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})/;
my $ad16 = qr/(0x[[:xdigit:]]{4}|\w+)/;
my @parser = (
	[ qr/LD\s+$reg8\s*,\s*$val8/,    'LD$1D $2' ],
	[ qr/LD\s+$reg8\s*,\s*$reg8/,    'MV$2$1'   ],
	[ qr/LD\s+$reg8\s*,\s*$ad16/,    'LD$1 $2'  ],
	[ qr/LD\s+([AB])\s*,\s*\(HL\)/,  'LD$1I'    ],
	[ qr/LD\s+$ad16\s*,$reg8/,       'ST$2 $1'  ],
	[ qr/LD\s+\(HL\)\s*,\s*([AB])/,  'ST$1I'    ],
	[ qr/LD\s+SP\s*,\s*$ad16/,       'LDSPD $1' ],
	[ qr/LD\s+HL\s*,\s*$ad16/,       'LDHLD $1' ],
	[ qr/XCH\s+A\s*,\s*B/,           'XAB'      ],
	[ qr/XCH\s+B\s*,\s*A/,           'XAB'      ],
	[ qr/(JMP|JSR|JN?[ZC])\s+$ad16/, '$1 $2'    ],
	[ qr/(NOP|HLT|RET)/,             '$1'       ],
	[ qr/([CZ](?:CLR|SET))/,         '$1'       ],
	[ qr/(TST|ADD|SUB|AND|OR|XOR|INV|SHL|SHR)/,
                                         '$1'       ],

);


# 0: LDA
# 1: LDB
# 2: LDH
# 3: LDL
# 4: LDAI
# 5: LDBI
# 8: LDAD
# 9: LDBD
# 10: LDHD
# 11: LDYD
# 16: STA
# 17: STB
# 18: STH
# 19: STL
# 20: STAI
# 21: STBI
# 32: LDSPD
# 80: MVAB
# 81: MVBA
# 82: XAB
# 128: JMP
# 129: JSR
# 130: RET
# 255: HLT

my %labels;

my $org=0;
my @mem;
my @patch;


sub parse_val
{
	/^"(.*)"$/ and do {
		$mem[$org++] = ord
			for split //, $1;
		return;
	};
	/^0x([[:xdigit:]]{4})$/ and do {
		my $val = hex($1);
		$mem[$org++] = ($val&0xff00)>>8;
		$mem[$org++] = $val&0x00ff;
		return;
	};
	/^0x([[:xdigit:]]{2})$/ and do {
		$mem[$org++] = hex($1);
		return;
	};
	/^(\d+)$/ and do {
		$mem[$org++] =  $1;
		return;
	};
	/^'(.)'$/ and do {
		$mem[$org++] = ord($1);
		return;
	};
	/^(\w+)$/ and do {
		push @patch, [ $org, $1 ];
		$org += 2;
		return;
	};
	die "Internal error, cannot recognize argument $_ on line $.";
}



LINE:
while (<>) {
	chomp;
	s/^\s+//;
	s/\s+$//;
	/^;/ and next;
	/^$/ and next;

	/^(\w+):$/ and do {
		$labels{$1} = $org;
		next LINE;
	};

	if (s/^DATA\s+//) {
		parse_val for split ' ';
		next LINE;
	}
	my $line = $_;
	for (@parser) {
		my ($re, $repl) = $_->@*;
		if ($line =~ m{^$re$}) {
			eval "\$line =~ s{^$re\$}{$repl}"; die if $@;
			my @x = split(' ', $line);
			#dd @x;
			my $mne = shift @x;
			my $opc = $ilist->{$mne}//die "Internal error, unknown mnemonic '$mne'";
			$mem[$org++] = $opc;
			parse_val for @x;
			next LINE;
		}

	}
	die "Syntax error at line $.: $line\n";
}
#dd @patch;
for (@patch) {
	my ($org,$lbl) = $_->@*;
	my $target = $labels{$lbl} // die "Unknown label $lbl";
	$mem[$org++] = ($target&0xff00)>>8;
	$mem[$org++] = $target&0x00ff;
}
#dd @mem;
open my $fh, '>', 'image.img' or die $!;
binmode $fh;
print $fh chr for @mem;


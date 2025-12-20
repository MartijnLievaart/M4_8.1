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
	[ qr/LD\s+$reg8\s*,\s*$ad16/,    'LD$1 $2'  ],
	[ qr/LD\s+([AB])\s*,\s*,\(HL\)/, 'LD$1I'    ],
	[ qr/ST\s+$ad16\s*,$reg8/,       'ST$2 $1'  ],
	[ qr/ST\s+\(HL\)\s*,\s*([AB])/,  'ST$1I'    ],
	[ qr/LD\s+SP\s*,\s*$ad16/,       'LDSPD $1' ],
	[ qr/LD\s+$reg8\s*,\s*$reg8/,    'MV$2$1'   ], # Only A and B implemented actualy
	[ qr/XCH\s+A\s*,\s*B/,           'XAB'      ],
	[ qr/XCH\s+B\s*,\s*A/,           'XAB'      ],
	[ qr/JMP\s+$ad16/,               'JMP $1'   ],
	[ qr/JSR\s+$ad16/,               'JSR $1'   ],
	[ qr/(NOP|HLT|RET)/,             '$1'       ],

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
	my $line = $_;
	for (@parser) {
		my ($re, $repl) = $_->@*;
		if ($line =~ m{^$re$}) {
			eval "\$line =~ s{^$re\$}{$repl}"; die if $@;
			my @x = split(/ /, $line);
			dd @x;
			my $opc = $ilist->{shift @x}//die;
			$mem[$org++] = $opc;
			for (@x) {
				/^0x([[:xdigit:]]{4})$/ and do {
					my $val = hex($1);
					$mem[$org++] = ($val&0xff00)>>8;
					$mem[$org++] = $val&0x00ff;
					last;
				};
				/^0x([[:xdigit:]]{2})$/ and do {
					$mem[$org++] = hex($1);
					last;
				};
				/^(\d+)$/ and do {
					$mem[$org++] =  $1;
					last;
				};
				/^'(.)'$/ and do {
					$mem[$org++] = ord($1);
					last;
				};
				/^(\w+)$/ and do {
					push @patch, [ $org, $1 ];
					$org += 2;
					last;
				};
				die "Internal error, cannot recognize argument $_ on line $.";

			}
			next LINE;
		}

	}
	die "Syntax error at line $.: $line";
}
dd @patch;
for (@patch) {
	my ($org,$lbl) = $_->@*;
	my $target = $labels{$lbl} // die "Unknown label $lbl";
	$mem[$org++] = ($target&0xff00)>>8;
	$mem[$org++] = $target&0x00ff;
}
dd @mem;
open my $fh, '>', 'image.img' or die $!;
binmode $fh;
print $fh chr for @mem;


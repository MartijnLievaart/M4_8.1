#!/usr/bin/perl

use 5.34.0;
use warnings;
use feature qw(signatures);
no warnings qw(experimental::signatures);

use YAML::XS;
use Data::Dump;
use Getopt::Long qw/:config gnu_getopt/;

my $outfile = 'image.img';

GetOptions(
	'outfile|o=s' => \$outfile,
) or usage();

usage() if @ARGV != 1;
my $infile = $ARGV[0];

my $ilist = YAML::XS::LoadFile('instructions.yaml');
$ilist = { reverse %$ilist };
#dd $ilist;

my $reg8 = qr/([ABHL])/;
my $val8 = qr/('.'|0x[[:xdigit:]]{2}|25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})/;
my $ad16 = qr/(0x[[:xdigit:]]{4}|\w+)/;
my @parser = (
	{ match =>  qr/LD\s+$reg8\s*,\s*$val8/,    replace => 'LD$1D $2' },
	{ match =>  qr/LD\s+$reg8\s*,\s*$reg8/,    replace => 'MV$2$1'   },
	{ match =>  qr/LD\s+$reg8\s*,\s*$ad16/,    replace => 'LD$1 $2'  },
	{ match =>  qr/LD\s+([AB])\s*,\s*\(HL\)/,  replace => 'LD$1I'    },
	{ match =>  qr/LD\s+$ad16\s*,$reg8/,       replace => 'ST$2 $1'  },
	{ match =>  qr/LD\s+\(HL\)\s*,\s*([AB])/,  replace => 'ST$1I'    },
	{ match =>  qr/LD\s+SP\s*,\s*$ad16/,       replace => 'LDSPD $1' },
	{ match =>  qr/LD\s+HL\s*,\s*$ad16/,       replace => 'LDHLD $1' },
	{ match =>  qr/XCH\s+A\s*,\s*B/,           replace => 'XAB'      },
	{ match =>  qr/XCH\s+B\s*,\s*A/,           replace => 'XAB'      },
	{ match =>  qr/(JMP|JSR|JN?[ZC])\s+$ad16/, replace => '$1 $2'    },
	{ match =>  qr/(NOP|HLT|RET)/,             replace => '$1'       },
	{ match =>  qr/([CZ](?:CLR|SET))/,         replace => '$1'       },
	{ match =>  qr/TST\s+A\s*,\s*B/,           replace => 'TSTZAB'   },
	{ match =>  qr/TST\s+A\s*,\s*0/,           replace => 'TSTZA0'   },
	{ match =>  qr/TST\s+A\s*,\s*$val8/,       replace => 'TSTZAD $1'},
	{ match =>  qr/(ADD|SUB|AND|OR|XOR|INV|SHL|SHR)\s+A\s*,\s*B/,
                                         	   replace => '$1B'      },
	{ match =>  qr/(ADD|SUB|AND|OR|XOR|INV|SHL|SHR)\s+A\s*,\s*$val8/,
                                                   replace => '$1D $2'   },

);


my %labels;

my $org=0;
my @mem;
my @patch;
my %lst;

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

open my $in, '<', $infile or die "Cannot open $infile: $!\n";

LINE:
while (<$in>) {
	my $orgline = $_;
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
		$lst{$org} = $orgline;
		parse_val for val_split($_);
		next LINE;
	}
	my $line = $_;
	for (@parser) {
		my ($re, $repl) = @{$_}{'match', 'replace'};
		if ($line =~ m{^$re$}) {
			$lst{$org} = $orgline;
			eval "\$line =~ s{^$re\$}{$repl}"; die if $@;
			my @x = val_split($line);
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
open my $img, '>', $outfile or die $!;
say $img "v3.0 hex words addressed";
for my $l (0 .. int((@mem+15)/16)-1) {
	my $y = $l*16;
	printf($img "%04x:", $y);
	for my $x (0 .. 15) {
		printf($img " %02x", $mem[$y+$x]//0);
	}
	print($img "\n");
}	


my %slebal;
while (my ($lbl, $o) = each %labels) {
	push $slebal{$o}->@*, $lbl;
}

open my $list, '>', 'list.lst' or die $!;
for my $org (sort { $a <=> $b } keys %lst) {
	if ($slebal{$org}) {
		for ($slebal{$org}->@*) {
			printf $list "%04X\t%s:\n", $org, $_;
		}
	}
	printf $list "%04X\t%s", $org, $lst{$org};
}

exit;

sub val_split($line)
{
	my @ret;
	$line =~ s/^\s+//;
	while ($line gt '') {

		if ($line =~ s/^("[^"]+")//) {
			push @ret, $1;
		} elsif ($line =~ s/^'\\''//) {
			push @ret, ord("'");
		} elsif ($line =~ s/^('[^']')//) {
			push @ret, $1;
		} elsif ($line =~ s/(\S+)//) {
			push @ret, $1;
		} else {
			die "Cannot parse values: '$line'\n";
		}
		$line =~ s/^\s+//;
	}
	@ret;
}

sub usage()
{
	die "usage: $0 [ -o <imagefile> ] <asmfile>\n";
}

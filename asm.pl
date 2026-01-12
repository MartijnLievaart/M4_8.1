#!/usr/bin/perl

use 5.34.0;
use warnings;
use feature qw(signatures);
no warnings qw(experimental::signatures);

use YAML::XS;
use Data::Dump;
use Getopt::Long qw/:config gnu_getopt/;

my $outfile = 'image.img';
my $docs;

GetOptions(
	'outfile|o=s' => \$outfile,
	'docs'        => \$docs,
) or usage();

my $reg8 = qr/([ABHL])/;
my $val8 = qr/('.'|0x[[:xdigit:]]{2}|25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})/;
my $ad16 = qr/(0x[[:xdigit:]]{4}|\w+)/;
my @parser = (
	{
                match =>  qr/LD\s+$reg8\s*,\s*$val8/,
                replace => 'LD$1D $2',
                doc => <<HERE,
LD <reg8>,<value>

Load an 8 bit register with a direct value.
HERE
	},
	{
                match =>  qr/LD\s+$reg8\s*,\s*$reg8/,
                replace => 'MV$2$1',
                doc => <<HERE,
LD <reg8>,<reg8>

Load an 8 bit register from another 8 bit register.
HERE
        },
	{
                match =>  qr/LD\s+$reg8\s*,\s*$ad16/,
                replace => 'LD$1 $2',
                doc => <<HERE,
LD <reg8>,<address or label>

Load an 8 bit register from a memory location.
HERE
        },
	{
                match =>  qr/LD\s+([AB])\s*,\s*\(HL\)/,
                replace => 'LD$1I',
                doc => <<HERE,
LD <reg8>,(HL)

Load an 8 bit register from a memory location pointed to by HL.
HERE
        },
	{
                match =>  qr/LD\s+$ad16\s*,$reg8/,
                replace => 'ST$2 $1',
                doc => <<HERE,
LD <address or label>,<reg8>

Store an 8 bit register to a memory location.
HERE
        },
	{
                match =>  qr/LD\s+\(HL\)\s*,\s*([AB])/,
                replace => 'ST$1I',
                doc => <<HERE,
LD (HL),<reg8>

Store an 8 bit register to a memory location pointed to HL.
HERE
        },
	{
                match =>  qr/LD\s+SP\s*,\s*$ad16/,
                replace => 'LDSPD $1',
                doc => <<HERE,
LD SP,<address or label>

Load SP with a 16 bit value.
HERE
        },
	{
                match =>  qr/LD\s+HL\s*,\s*$ad16/,
                replace => 'LDHLD $1',
                doc => <<HERE,
LD HL,<address or label>

Load HL with a 16 bit value.
HERE
        },
	{
                match =>  qr/XCH\s+A\s*,\s*B/,
                replace => 'XAB',
                doc => <<HERE,
XCH A,B

Exchange registers A and B
HERE
        },
	{
                match =>  qr/(JMP|JSR|JN?[ZC])\s+$ad16/,
                replace => '$1 $2',
                doc => <<HERE,
JMP, JSR, JZ, JNZ, JC, JNC

Jump, jump to subroutine, conditional jumps. Always takes an absolute 16 bit address (or label).
HERE
        },
	{
                match =>  qr/(NOP)/,
                replace => '$1',
                doc => <<HERE,
NOP

Do nothing
HERE
        },
	{
                match =>  qr/(HLT)/,
                replace => '$1',
                doc => <<HERE,
HLT

Stop running until the run button is pressed.
HERE
        },
	{
                match =>  qr/(RET)/,
                replace => '$1',
                doc => <<HERE,
RET

Return from subroutine
HERE
        },
	{
                match =>  qr/([CZ](?:CLR|SET))/,
                replace => '$1',
                doc => <<HERE,
CCLR, CSET, ZCLR, ZSET

Clear or set the carry or zero flag.
HERE
        },
	{
                match =>  qr/TST\s+A\s*,\s*B/,
                replace => 'TSTZAB',
                doc => <<HERE,
TST A,B

Test the A and B register, set the zero flag if they are equal, carry if B is larger than A.
HERE
        },
	{
                match =>  qr/TST\s+A\s*,\s*0/,
                replace => 'TSTZA0',
                doc => <<HERE,
TST A,0

Test if A is zero. If so, set the zero flag.
HERE
        },
	{
                match =>  qr/TST\s+A\s*,\s*$val8/,
                replace => 'TSTZAD $1',
                doc => <<HERE,
TST A,<value>

Test the A and a direct value, set the zero flag if they are equal, carry if the value is larger than A.
HERE
        },
	{
                match =>  qr/(INV|SHL|SHR)/,
                replace => '$1',
                doc => <<HERE,
INV, SHL, SHR

Invert, shift left or shift right of the A register. Shifts use theh carry flag both as input on one side as output on the other.
HERE
        },
	{
                match =>  qr/(ADD|SUB|AND|OR|XOR)\s+A\s*,\s*B/,
                replace => '$1B',
                doc => <<HERE,
ADD A,B
SUB A,B
AND A,B
OR  A,B
XOR A,B

Execute the arithmetic or logic instruction on registers A and B.
HERE
        },
	{
                match =>  qr/(ADD|SUB|AND|OR|XOR)\s+A\s*,\s*$val8/,
                replace => '$1D $2',
                doc => <<HERE,
ADD A,<value>
SUB A,<value>
AND A,<value>
OR  A,<value>
XOR A,<value>

Execute the arithmetic or logic instruction on registers A and a direct value.
HERE
        },

);

if ($docs) {
	usage() if @ARGV;
	say sort map { "------\n\n$_->{doc}\n" } @parser;
	exit;
}

usage() if @ARGV != 1;
my $infile = $ARGV[0];

my $ilist = YAML::XS::LoadFile('instructions.yaml');
$ilist = { reverse %$ilist };
#dd $ilist;


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

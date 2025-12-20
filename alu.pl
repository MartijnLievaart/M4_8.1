#!/usr/bin/perl

use 5.34.0;
use warnings;
use feature qw(signatures);
no warnings qw(experimental::signatures);

use Data::Dump;

use constant BITS  => 4;
use constant MASK  => (1<<BITS)-1;
use constant RMASK => (1<<(BITS+1))-1;
my @c = (
	{ op => 'ADD', x => sub($a, $b, $c) { $a+$b+$c } },
	{ op => 'SUB', x => sub($a, $b, $c) { $a-$b-$c } },
	{ op => 'AND', x => sub($a, $b, $c) { $a&$b } },
	{ op => 'OR',  x => sub($a, $b, $c) { $a|$b } },
	{ op => 'XOR', x => sub($a, $b, $c) { $a^$b } },
	{ op => 'INV', x => sub($a, $b, $c) { (~$a)&MASK } },
	{ op => 'SHL', x => sub($a, $b, $c) { ($a<<1)+$c } },
	{ op => 'SHR', x => sub($a, $b, $c) { my $nc = $a&1; ($a>>1) | ($c<<(BITS-1)) | ($nc<<BITS) } },
	);
#dd \%c;

my $ad=0;
my @mem;
for my $op (@c) {
	for my $a (0..MASK) {
		for my $b (0..MASK) {
			for my $c (0..1) {
				$mem[$ad] = $op->{x}($a, $b, $c) & RMASK;
				#say sprintf("%04X %02X %X %X %X %s", $ad, $mem[$ad], $a, $b, $c, $op->{op});
				$ad++;
			}
		}
	}
}

#dd \@mem;
#say scalar @mem;
open my $fh, '>', 'alu.img' or die;
binmode $fh;
my $n=0;
for (@mem) {
	printf $fh "%02X", $_ ;
	print $fh (++$n%16==0) ? "\n" : ' ';
}

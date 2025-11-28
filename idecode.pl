#!/usr/bin/perl

use 5.34.0;
use warnings;
use feature qw(signatures);
no warnings qw(experimental::signatures);

use YAML::XS;
use List::MoreUtils;

use Data::Dump;

my $data = YAML::XS::LoadFile("idecode.yaml");

use constant DEBUG => 1;
use constant BITSIZE => 16;
use constant PHASES  => 4;
my $regoffset = { load => 2**8, bus => 2**12 };

my @ROM = map { 0 } (0..1023);


my $control_lines = parse_control_lines($data);
DEBUG and dd $control_lines;

#my $register_load = parse_registers('load', $data);
#dd $register_load;

#my $register_bus = parse_registers('bus', $data);
#dd $register_bus;

#my $register = { load => $register_load, bus => $register_bus };
my $registers = parse_registers($data);
DEBUG and dd $registers;

parse_instructions($data);

open my $img, '>', 'idecode.img' or die;
say $img "v3.0 hex words addressed";
for my $l (0 .. (1024/16)-1) {
	my $y = $l*16;
	printf($img "%03x:", $y);
	for my $x (0 .. 15) {
		printf($img " %04x", $ROM[$y+$x]);
	}
	print($img "\n");
}	
	
exit;



sub parse_control_lines($data)
{
	my @control = $data->{control_lines}->@*;
	my $n=0;
	return { map { $_, 2**$n++} @control };
}

sub regline($prefix, $n)
{
	return $regoffset->{$prefix}*$n;
}

sub parse_registers($data)
{
	my $reg;
	my %regdata = $data->{register_lines}->%*;
	while (my ($control_line, $register_data) = each %regdata) {
		my $offset = $register_data->{offset} // die "No offset for $control_line";
		my @regs = ($register_data->{regs} // die "No regs for $control_line")->@*;
		my $n=1;
		for (@regs) {
			$reg->{$control_line}->{$_} = ($n++) * $offset;
		}
	}
	return $reg;
}

sub parse_instructions($data)
{
	my %inst = $data->{instructions}->%*;
	dd %inst;
	while (my ($mnemonic, $i) = each %inst) {
		dd $i;
		my $op = $i->{op} // die;
		my @phases = $i->{ph}->@*;
		my $n = 1;
		for my $p (@phases) {
			my $v = parse_phase($p);
			$v |= $control_lines->{nxti}
				if $n == @phases;
			printf "$op\[$n\] => %04X\n", $v;
			$ROM[hex($op)*PHASES+$n++] = $v;
		}
	}	
}

sub parse_phase($phase)
{
	my @flags = split(/, */, $phase);
dd @flags;
	my $res;
	for my $f (@flags) {
		if ($f =~ /(.*)\((.*)\)/) {
			$f = $1;
			my $reg = $2;
			die "Not a compound: '$f'" unless exists $registers->{$f};
			die "Not a register for $f: '$reg'" unless exists $registers->{$f}->{$reg};

			$res += $registers->{$f}->{$reg};
		} else {
			die "Unknown control line $f" if not $control_lines->{$f};
			$res |= $control_lines->{$f};
		}
	}
	return $res;
}

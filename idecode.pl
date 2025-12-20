#!/usr/bin/perl

use 5.34.0;
use warnings;
use feature qw(signatures);
no warnings qw(experimental::signatures);

use YAML::XS;
use List::MoreUtils;

use Data::Dump;
use Getopt::Long;

my $infile = 'idecode.yaml';
my $debug  = 0;
GetOptions(	"infile|i=s" => \$infile,
		"debug|d"    => \$debug,
		) or die("Error in command line arguments\n");

my $data = YAML::XS::LoadFile("idecode.yaml");

my $bitsize   = $data->{bitsize} // die "No bitsize";
my $maxphases = $data->{phases}  // die "No #phases";
my $romsize   = $maxphases*256;

my @ROM = (0) x $romsize;


my $control_lines = parse_control_lines($data);
$debug and dd $control_lines;

my $registers = parse_registers($data);
$debug and dd $registers;

my $ilist = parse_instructions($data);
$YAML::XS::QuoteNumericStrings = 0;
YAML::XS::DumpFile('instructions.yaml', $ilist);

open my $img, '>', 'idecode.img' or die;
say $img "v3.0 hex words addressed";
for my $l (0 .. ($romsize/16)-1) {
	my $y = $l*16;
	printf($img "%04x:", $y);
	for my $x (0 .. 15) {
		printf($img " %04x", $ROM[$y+$x]);
	}
	print($img "\n");
}	


exit;



sub parse_control_lines($data)
{
	my @control = $data->{control_lines}->@*;
	my $n = ($data->{control_lines_offset} // die);
	my $r = {};
	for (@control) {
		$r->{$_} = $n;
		$n <<= 1;
	}
	return $r;
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
	my @inst = $data->{instructions}->@*;
	$debug and dd @inst;
	my $op = 0;
	my %done;
	for my $i (@inst) {
		$debug and dd($i);
		my $mnemonic = $i->{mne} // die;
		$op = $i->{op} ? hex($i->{op}) : $op+1;
		die sprintf("Duplicate opcode %02x, first used for %s, redefined for %s\n",
						$op, $done{$op}, $mnemonic)
			if $done{$op};

		my @phases = $i->{ph}->@*;
		my $n = 1;
		for my $p (@phases) {
			my $v = parse_phase($p);
			$v |= $control_lines->{nxti}
				if $n == @phases;
			$debug and printf "%02X\[$n\] => %04X\n", $op, $v;
			$ROM[$op*$maxphases+$n++] = $v;
		}
		$done{$op} = $mnemonic;
	}	
	return { %done };
}

sub parse_phase($phase)
{
	my @flags = split(/, */, $phase);
	$debug and dd @flags;
	my $res;
	for my $f (@flags) {
		if ($f =~ /(.*)\((.*)\)/) {
			$f = $1;
			my $reg = $2;
			die "Not a compound: '$f'" unless exists $registers->{$f};
			die "Not a register for $f: '$reg'" unless exists $registers->{$f}->{$reg};

			$res |= $registers->{$f}->{$reg};
			$res |= $control_lines->{$f} if exists $control_lines->{$f};

		} else {
			die "Unknown control line $f" if not $control_lines->{$f};
			$res |= $control_lines->{$f};
		}
	}
	return $res;
}

#!usr/bin/perl -w
use strict;

die "Usage: perl $0 [.fa] [out.fa]\n" unless (@ARGV == 2);
open (FA, $ARGV[0]) or die "$ARGV[0] $!\n";
open OT1, ">$ARGV[1]" or die "$ARGV[1] $!\n";
open OT2, ">$ARGV[1].removed" or die "$ARGV[1].removed $!\n";

my %CODE = ( # Animal MT condon table
                                'TAA' => 'U', 'TAG' => 'U'	              # Stop
);


$/=">";
<FA>;
while(<FA>){
	chomp;
	my @line = split /\n+/, $_;
	my $name = shift @line;
	my $seq = join "", @line;
	my @seq = split /\s*/, $seq;
	my $len = length $seq;
	my $phase = 1;
	my $stop = 0;

	for (my $i=$phase; $i<$len; $i+=3) {
		my $codon = substr($seq,$i,3);
		if($CODE{$codon}){
			$stop = 1;
		}
	}

	if($stop == 1){
		print OT2 ">$name\n$seq\n";
	}else{
		print OT1 ">$name\n$seq\n";
	}
}

close FA;
close OT1;
close OT2;
print "DONE!";

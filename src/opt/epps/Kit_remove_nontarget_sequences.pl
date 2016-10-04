#!usr/bin/perl -w
use strict;

die "Usage: perl $0 [hmm.fa] [in.spp.table] [out.spp.hmm.table]\n" unless (@ARGV == 3);
open (FA, $ARGV[0]) or die "$ARGV[0] $!\n";
open (TAB, $ARGV[1]) or die "$ARGV[1] $!\n";
open OUT, ">$ARGV[2]" or die "$ARGV[2] $!\n";

my %hash;

$/=">";
<FA>;
while(<FA>){
	chomp;
	my @line = split/\n+/;
	if($line[0] =~ /OTU\_(\d+)\;/){
		my $otu = $1;
		$hash{$otu} = 1;
	}
}
close FA;


$/="\n";
my $header = <TAB>;
print OUT "$header";
while(<TAB>){
	my $line = $_;
	my @line = split;

	if($hash{$line[0]}){
		print OUT "$line";
	}
}
close OUT;
print "DONE!";

#!usr/bin/perl -w
use strict;

die "Usage: perl $0 [uc file] [SAP csv file] [usearch assignment] [Output]\n" unless (@ARGV == 4);
open (IN, $ARGV[0]) or die "$ARGV[0] $!\n";
open OUT, ">$ARGV[3]" or die "$ARGV[3] $!\n";


open (SP, $ARGV[1]) or die "$ARGV[1] $!\n";

my (%hash, %spp, %samples, %usearch);
while(<SP>){
	chomp;
	my @line = split/\;/;
	my $spp = $line[-1];
	my @id = split/\,/, $line[0];
	my $otu = $id[-1];
	$otu =~ s/OTU\_//;
	$spp =~ s/\,//;
	$spp =~ s/\s+/\_/g;
	$spp{$otu} = $spp;
}
close SP;

open (SP, $ARGV[2]) or die "$ARGV[2] $!\n";
while(<SP>){
	chomp;
	my @line = split/\s+/;
	my @otu = split/\;/, $line[-2];
	$otu[0] =~ s/OTU\_//;
	$usearch{$otu[0]} = $line[-1].";".$line[3].";".$line[7];
}

while(<IN>){
	chomp;
	my @line = split/\s+/;
	my @sample = split /\_/, $line[-2];

pop @sample;
my $sample_id = join "\_", @sample;
if($samples{$sample_id}){
}else{
	$samples{$sample_id} = 1;
}

	if($line[-1] eq "*"){
		next;
	}else{
		my @otu = split /\_/, $line[-1];
		$hash{$otu[1]}{$sample_id} ++;
	}
}

my @samples = sort keys %samples;
my $header = join "\t", @samples;
print OUT "OTU_ID\t$header\tSAP\tUSEARCH\n";

foreach my $k (sort {$a<=>$b} keys %hash){
	print OUT "$k\t";
#	foreach my $l (sort keys %{$hash{$k}}){
	foreach my $l (@samples){
		if($hash{$k}{$l}){
			print OUT "$hash{$k}{$l}\t";
		}else{
			print OUT "0\t";
		}
	}
	if($spp{$k}){
		print OUT "$spp{$k}\t";
	}else{
		print OUT "NA,NA,NA,NA,NA,NA,0,0,0\t";
	}

	if($usearch{$k}){
		print OUT "$usearch{$k}\t";
	}else{
		print OUT "HMM_filtered\t";
	}

	print OUT "\n";
}
print "DONE!";

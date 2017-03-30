#!usr/bin/perl -w
use strict;

die "Usage: perl $0 [fq.infor] [primers.fas] [out.table]\n" unless (@ARGV == 3);
open FQ, "$ARGV[0]" or die "$ARGV[0] $!\n";
open PRI, "$ARGV[1]" or die "$ARGV[1] $!\n";

open OT, ">$ARGV[2]" or die "$ARGV[2] $!\n";

my (%raw_data);
#my $header = <FQ>;
while(<FQ>){
	chomp;
	my @line = split;
	my @id = split/\./, $line[0];
	$raw_data{$id[0]} = $line[1];
}
my %primers;
while(<PRI>){
	chomp;
	if(/^>/){
		my $line = $_;
		$line =~ s/\>//;
		my @line = split/\_/;
		$primers{$line[0]} = 1;
	}
}
my %demul;
foreach my $k (sort keys %raw_data){

	print OT "$k\t$raw_data{$k}\t";

	open DE, "$k\.demultiplex.infor" or die "$k\.demultiplex.infor $!\n";
	my $header = <DE>;
	while(<DE>){
		my @line = split;
		my $gene = shift @line;
		my $numbers = join "\t", @line;
		$demul{$k}{$gene} = $numbers;

		print OT "$gene\t$numbers\t";

		open MG, "$k\_$gene\.merged.fastq" or die "$k\_$gene\.merged.fastq $!\n";
		my $fq = 0;
		while(<MG>){
			$fq ++;
		}
		close MG;

		$fq = $fq / 4;
		print OT "$fq\t";

		my $fa = 0;
		open MG, "$k\_$gene\.merged.fasta" or die "$k\_$gene\.merged.fasta $!\n";
		while(<MG>){
			if(/^>/){
				$fa ++;
			}
		}
		close MG;
		
		print OT "$fa\t";
		$demul{$k}{$gene} .= $fq."\t".$fa;
	}
	print OT "\n";
}




close FQ;
close PRI;
close OT;
print "DONE!";

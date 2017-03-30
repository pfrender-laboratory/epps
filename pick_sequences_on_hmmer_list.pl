#!usr/bin/perl -w
use strict;

die "perl $0 [fasta] [.nhmmer.blast] [output file]\n" unless @ARGV == 3;

my %hash;
open (LS, "$ARGV[1]") or die "$ARGV[1] $!\n";
while(<LS>){
	chomp;

	if(/^#/){
		next;
	}else{
		my @line = split;
		$hash{$line[0]} ++;
#		print "### $line[0]\n";
	}
}
close LS;

open (IN, "$ARGV[0]") or die "$ARGV[0] $!\n";
open (OUT, ">$ARGV[2]") or die "$ARGV[2] $!\n";
open (RM, ">$ARGV[2].removed") or die "$ARGV[2].removed $!\n";

$/=">";
<IN>;
while(<IN>){
	chomp;
	my $all = $_;
	my @line = split /\n+/;
	my $id = shift @line;
	my $seq = join "", @line;
#	my @names = split /\_/, $line[0];
#	if($hash{$names}){
	my @id = split /\s+/, $id;

#	print "### $id[0]\n";

	if(($hash{$id[0]})&&($hash{$id[0]} == 1)){
		$/="\n";
#		print OUT ">$id\n$seq\n";
		print OUT ">$all";
		$/=">";
	}else{
		$/="\n";
		print RM ">$all";
		$/=">";
	}

}
close IN;

#!usr/bin/perl -w
use strict;

die "Usage: perl $0 [uc file] [SAP csv file] [Output]\n" unless (@ARGV == 3);
open (IN, $ARGV[0]) or die "$ARGV[0] $!\n";
open OUT, ">$ARGV[2]" or die "$ARGV[2] $!\n";


open (SP, $ARGV[1]) or die "$ARGV[1] $!\n";

my (%hash, %spp, %sample);
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

while(<IN>){
        chomp;
        my @line = split/\s+/;
        my @sample = split /\_/, $line[-2];

pop @sample;
my $sample_id = join "\_", @sample;
$sample{$sample_id} ++;


        if($line[-1] eq "*"){
                next;
        }else{
                my @otu = split /\_/, $line[-1];
                $hash{$otu[1]}{$sample_id} ++;
        }
}

my @samples = sort keys %sample;
my $header = join "\t", @samples;
print OUT "OTU_ID\t$header\tSAP\n";

foreach my $k (sort {$a<=>$b} keys %hash){
        print OUT "$k\t";
#       foreach my $l (sort keys %{$hash{$k}}){
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
        print OUT "\n";
}
print "DONE!";

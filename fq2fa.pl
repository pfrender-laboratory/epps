#!usr/bin/perl -w
use strict;

die "Usage: perl $0 [.fq] \n" unless (@ARGV == 1);

### Check fq.gz
if ($ARGV[0] =~ /gz$/){
        open FQ, "gzip -dc $ARGV[0] |" || die "$!\n";
} else {
        open FQ, "<$ARGV[0]" || die "$!\n";
}

#open (FQ, $ARGV[0]) or die "$ARGV[0] $!\n";
open FA, ">$ARGV[0].fa" or die "$ARGV[0].fa $!\n";
my $null;



while(<FQ>){
        if(/^@/){
                print FA ">$_";
                $null = <FQ>;
                print FA "$null";
                $null = <FQ>;
                $null = <FQ>;
        }
}
print "DONE!\n";
close FA;
close FQ;

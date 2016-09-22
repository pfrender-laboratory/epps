#!usr/bin/perl -w
use strict;

die "Usage: perl $0 [.fa] [Number of reads per job] [out direction]\n" unless (@ARGV == 3);

mkdir($ARGV[2]) unless(-d $ARGV[2]);
my $num = $ARGV[1];
my $split = $num;
open (FA, $ARGV[0]) or die "$ARGV[0] $!\n";
$/=">";
<FA>;
my $count = 1;
#my $name;

open OUT, ">$ARGV[2]/$ARGV[0].$count.fas" or die "$ARGV[2]/$ARGV[0].$count.fas $!\n";
while(<FA>){
	chomp;
	my @all = split /\n+/; 
	my $name = shift @all;
	my $seq = join "", @all;

	$name =~ s/\=//;
	
	if($split){
		print OUT ">$name\n$seq\n";
		$split --;
	}else{
		$split = $num;
		$count++;
		close OUT;
		open OUT, ">$ARGV[2]/$ARGV[0].$count.fas" or die "$ARGV[2]/$ARGV[0].$count.fas $!\n";
		print OUT ">$name\n$seq\n";
	}
	
}

open OUT, ">$ARGV[2]/$ARGV[0].sap.sh" or die "$ARGV[2]/$ARGV[0].sap.sh $!\n";
print OUT "\#\!/bin/csh
\#\$ -N $ARGV[2].sap.sh
\#\$ -t 1\-$count:1
\#\$ -r y
module load python/2.7.11
/afs/crc.nd.edu/user/y/yli19/bin/SAP//bin/sap $ARGV[0].\${SGE_TASK_ID}.fas -d $ARGV[0].\${SGE_TASK_ID} --svg -e yli19\@nd.edu\n";
close OUT;
print "DONE!";

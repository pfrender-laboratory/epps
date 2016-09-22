#!usr/bin/perl -w
use strict;

die "Usage: perl $0 [.fa] [#splits] [output prefix]\n" unless (@ARGV == 3);
open (FA, $ARGV[0]) or die "$ARGV[0] $!\n";
my $split = $ARGV[1];
my $seq;
my @raw;
my $line_id = 0;

$/ = ">";
<FA>;
while(<FA>){
	chomp;
	$line_id ++;
}
close FA;
my $sub = int($line_id / $split) + 1;
print "In total, there are $line_id sequences.\n In each file, there are $sub sequences\n";

my $count_lines = 1;
my $count_files = 1;
open (FA, $ARGV[0]) or die "$ARGV[0] $!\n";
open OUT, ">$ARGV[2].$count_files.fas" or die "$ARGV[2].$count_files.fas $!\n";
<FA>;
while(<FA>){
	chomp;
	
	if($count_lines <= $sub){
		print OUT ">$_";
		$count_lines ++;
	}else{
		close OUT;
		$count_files ++;
		$count_lines = 1;
		open OUT, ">$ARGV[2].$count_files.fas" or die "$ARGV[2].$count_files.fas $!\n";
		print OUT ">$_";
		$count_lines ++;
	}
}


close FA;
close OUT;
print "DONE!";

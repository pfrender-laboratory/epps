#! usr/bin/perl -w
use strict;

die "Usage: perl $0 <reads.fq> <.....> Or <reads.fq.gz> <.....>\n  -----yy\n" unless(@ARGV>=1);

my (@temp, $total, $eff, $num, $reads, $gc, $gc_con, $Q20, $Q30, $output);
#print "\t\t\tReadNum\t\tTotalLen\tEffectiveLen\tGC_content\tQ20 ratio\tQ30 ratio\n";
$output = "\t\t\tReadNum\t\tTotalLen\tEffectiveLen\tGC_content\tQ20 ratio\tQ30 ratio\n";
foreach my $k(0..$#ARGV){
	$total=0;
	$eff=0;
	$num=0;
	$gc = 0;
	$Q20 = 0;
	$Q30 = 0;

    $reads=$ARGV[$k];
#    print "$reads\t";
	$output .= "$reads\t";

###############################
        if ($reads =~ /gz$/){
                open IN, "gzip -dc $reads |" || die "$!\n";
        } else {
                open IN, "<$reads" || die "$!\n";
        }
##############################

    while(<IN>){
	if(/^@/){
		my $seq = <IN>;
		<IN>;
		my $qual = <IN>;
	        chomp $seq;
		chomp $qual;
		
		my @qual = split /\s*/, $qual;

		foreach my $q (@qual){
			$q = ord ($q) - 33;
#print "$q\n";
			if($q >=20){
				$Q20 ++;
			}
			if($q >=30){
				$Q30 ++;
			}
		}

        	$total += length($seq);
	        $seq =~ s/N//g;
	        $eff += length($seq);
		$gc += ($seq=~tr/GC/GC/);
	        $num++;
	}else{
#		print "$_\tInput format error\n";
		$output .= "$_\tInput format error\n";
	}
    }
	if($eff){
	        $gc_con = $gc / $eff;
	}else{
		$gc_con = 0;
	}

	if($total){
		$Q20 = $Q20/$total;
		$Q30 = $Q30/$total;
	}else{
		$total = 0;
	}

#    print "\t$num\t$total\t$eff\t$gc_con\t$Q20\t$Q30\n";
	$output .= "\t$num\t$total\t$eff\t$gc_con\t$Q20\t$Q30\n";
    close IN;
    $/="\n";
}

print "$output";

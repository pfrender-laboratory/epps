#!usr/bin/perl -w
use strict;
use FindBin qw($Bin $Script);
use File::Basename qw(basename dirname);
use Getopt::Long;
use Cwd;
#use Cwd 'abs_path';
#my $abs_path = abs_path($file);

=head1 Usage:
        perl eDNA_pipeline.pl -l [fq list] -o [output directory] -pm [primer set] -p [output file prefix]

=head1 Version

	V1.0 GitHub version 1.0

=cut

my ($list, $directory, $prefix, $primer, $demul, $array, $Help, $job_num);

GetOptions(
	"l:s"=>\$list,
	"o:s"=>\$directory,
	"p=s"=>\$prefix,
	"pm=s"=>\$primer,
#	"dm=s"=>\$demul,
	"h"=>\$Help
	
);
die `pod2text $0` if ((not defined $list) || (not defined $directory) || (not defined $prefix) || $Help );

my $dir = getcwd;
$primer = $dir."/".$primer;
print "$primer\n";

die `pod2text $0` if ((not defined $list) || (not defined $directory) || (not defined $prefix) || $Help );

my %files;

mkdir("$directory\/Samples") unless(-d "$directory\/Samples");

open (LS, $list) or die "$list $!\n";
while(<LS>){
	chomp;

	my $file_name;
	my $path = $_;
	my @line = split/\//, $path;
	my @id = split/\./, $line[-1];

	$id[0] =~ s/\-/\_/;
	my $folder;
	if($prefix eq "NA"){
	        $file_name = $id[0];
	}else{
	        $file_name = $prefix.$id[0];
	}

	my $fq; 
	if($id[-2] eq "1"){
		$fq = 1;
	}elsif($id[-2] eq "2"){ 
	        $fq = 2;
	}else{
		print "fq.list format error\n";
		exit;
	}

		`ln -s $path $directory\/Samples\/$file_name.$fq.fq`;
		$file_name = "\"".$file_name."\"";
		$files{$file_name} = 1;
	}
	close LS;

	my @files = sort keys %files;
	$job_num = @files;
	$array = join ",", @files;

	foreach my $file (@files){

	print "$file\n";
	print "1. Calculating Read Number\n";
	system "perl $Bin/fq_status_V1.2.pl $directory\/Samples\/$file.1.fq $directory\/Samples\/$file.2.fq > $directory\/Samples\/$file.fq.infor";

	print "2. Sequencing Adaptor Removal\n";
	system "java -jar $Bin/trimmomatic-0.32.jar PE -phred33 -trimlog trim.log $directory\/Samples\/$file.1.fq $directory\/Samples\/$file.2.fq $directory\/Samples\/$file.1.pe.fq $directory\/Samples\/$file.1.se.fq $directory\/Samples\/$file.2.pe.fq $directory\/Samples\/$file.2.se.fq ILLUMINACLIP:$Bin/primers/MiSeq.adapter.fas:3:30:6:1:true SLIDINGWINDOW:10:20 MINLEN:50 > $directory\/Samples\/$file.trimmomatic.log";

# Demultiplex and remove primer (100% identical). Reads were re-orientated based on primer
	print "3. Demultiplexing\n";
	system "perl $Bin/Demultiplex_primer_v1.4.pl $directory\/Samples\/$file.1.pe.fq $directory\/Samples\/$file.2.pe.fq $primer $directory\/Samples\/$file $directory\/Samples\/$file.demultiplex.infor";

	}

my %hash;
open (PRI, $primer) or die "Primers $!\n";
$/ = '>';
<PRI>;
while(<PRI>){
        chomp;
        my @line = split /\n+/;
        my @id = split /\_/, $line[0];
        $hash{$id[0]} ++;
}
close PRI;


foreach my $k (keys %hash){
	foreach my $file (@files){
		print "4. Merging and quality filtering: $k\t$file\n";
# To remove \"staggered\" overlaps & Merge paired-end reads
		system "$Bin/usearch -fastq_mergepairs $directory\/Samples\/$file\_$k.F.fq -reverse $directory\/Samples\/$file\_$k.R.fq -fastqout $directory\/Samples\/$file\_$k.merged.fastq -fastq_allowmergestagger";
# Quality filtering
		system "$Bin/usearch -fastq_filter $directory\/Samples\/$file\_$k.merged.fastq -fastq_maxee 0.5 -fastaout $directory\/Samples\/$file\_$k.merged.fasta -fastq_maxns 1";

# Send to Report
#		system "perl /afs/crc.nd.edu/group/pfrenderlab/kimura/yli19/bin/shortcuts/fq_status_V1.1.pl $directory\/Samples\/$file\_$k.F.fq $directory\/Samples\/$file\_$k.R.fq $directory\/Samples\/$file\_$k.merged.fastq > $directory\/Samples\/$file\_$k.report";

# Rename fasta for dereplication
		print "5. Renaming fasta files $k\t$file\n";
		system "perl $Bin/rename_4.0.pl $directory\/Samples\/$file\_$k.merged.fasta $file  $directory\/Samples\/$file\_$k.rename.fas";
	}
}

foreach my $k (keys %hash){
	print "6. Dereplication: $k\n";
	system "cat ./Samples/*_$k.rename.fas > All_$k.rename.fas";
# Dereplication
	system "perl $Bin/unique.pl All_$k.rename.fas All_$k.rename.unique.fas";
	system "$Bin/usearch -sortbysize All_$k.rename.unique.fas -fastaout All_$k.rename.unique.sorted.fasta -minsize 2";

# OTU clustering
	print "7. OTU clustering\n";
	system "$Bin/usearch -cluster_otus All_$k.rename.unique.sorted.fasta -otus All_$k.OTU.fasta -sizein -sizeout -uparseout All_$k.OTU.fasta.up";
	system "$Bin/usearch -sortbysize All_$k.OTU.fasta -fastaout All_$k.OTU.sorted.fasta";

# count OTU size
	print "8. OTU size counting\n";
	system "perl $Bin/rename_4.0.pl All_$k.OTU.sorted.fasta OTU  All_$k.OTU.ID.fasta";

	system "perl $Bin/split_fasta.pl All_$k.rename.fas 10 All_$k.rename.split";
	system "$Bin/usearch -usearch_global All_$k.rename.split.1.fas  -db All_$k.OTU.ID.fasta -strand plus -id 0.97 -uc All_$k.OTU.ID.uc.1 -maxrejects 128";
	system "$Bin/usearch -usearch_global All_$k.rename.split.2.fas  -db All_$k.OTU.ID.fasta -strand plus -id 0.97 -uc All_$k.OTU.ID.uc.2 -maxrejects 128";
	system "$Bin/usearch -usearch_global All_$k.rename.split.3.fas  -db All_$k.OTU.ID.fasta -strand plus -id 0.97 -uc All_$k.OTU.ID.uc.3 -maxrejects 128";
	system "$Bin/usearch -usearch_global All_$k.rename.split.4.fas  -db All_$k.OTU.ID.fasta -strand plus -id 0.97 -uc All_$k.OTU.ID.uc.4 -maxrejects 128";
	system "$Bin/usearch -usearch_global All_$k.rename.split.5.fas  -db All_$k.OTU.ID.fasta -strand plus -id 0.97 -uc All_$k.OTU.ID.uc.5 -maxrejects 128";
	system "$Bin/usearch -usearch_global All_$k.rename.split.6.fas  -db All_$k.OTU.ID.fasta -strand plus -id 0.97 -uc All_$k.OTU.ID.uc.6 -maxrejects 128";
	system "$Bin/usearch -usearch_global All_$k.rename.split.7.fas  -db All_$k.OTU.ID.fasta -strand plus -id 0.97 -uc All_$k.OTU.ID.uc.7 -maxrejects 128";
	system "$Bin/usearch -usearch_global All_$k.rename.split.8.fas  -db All_$k.OTU.ID.fasta -strand plus -id 0.97 -uc All_$k.OTU.ID.uc.8 -maxrejects 128";
	system "$Bin/usearch -usearch_global All_$k.rename.split.9.fas  -db All_$k.OTU.ID.fasta -strand plus -id 0.97 -uc All_$k.OTU.ID.uc.9 -maxrejects 128";
	system "$Bin/usearch -usearch_global All_$k.rename.split.10.fas  -db All_$k.OTU.ID.fasta -strand plus -id 0.97 -uc All_$k.OTU.ID.uc.10 -maxrejects 128";
	system "cat All_$k.OTU.ID.uc.1 All_$k.OTU.ID.uc.2 All_$k.OTU.ID.uc.3 All_$k.OTU.ID.uc.4 All_$k.OTU.ID.uc.5 All_$k.OTU.ID.uc.6 All_$k.OTU.ID.uc.7 All_$k.OTU.ID.uc.8 All_$k.OTU.ID.uc.9 All_$k.OTU.ID.uc.10 > All_$k.OTU.ID.uc";

	system "$Bin/usearch -usearch_global All_$k.rename.fas -db All_$k.OTU.ID.fasta -strand plus -id 0.97 -uc All_$k.OTU.ID.uc";

	system "less -S All_$k.OTU.ID.uc| perl -e \'while(<>){\@s=split; if(\$s[-1] eq \"\*\"){}else{\$hash{\$s[-1]} ++;} } foreach my \$k (sort {\$hash{\$b}<=>\$hash{\$a}} keys %hash){ print \"\$k\\t\$hash{\$k}\\n\"; }\' > All_$k.OTU.ID.uc.summary";

	system "perl $Bin/add_abundance.pl All_$k.OTU.ID.fasta All_$k.OTU.ID.uc.summary NA All_$k.OTU.ID.abund.fasta";


###
# HMMer
###
	print "9. HMMER filtering $k\n";
	system "$Bin/nhmmer --tblout All_$k.OTU.ID.abund.fasta.nhmmer.blast -o All_$k.OTU.ID.abund.fasta.nhmmer -E 1e-10 $Bin/hmm/$k\_DB.rename.aln.hmm All_$k.OTU.ID.abund.fasta";
	system "perl $Bin/pick_sequences_on_hmmer_list.pl All_$k.OTU.ID.abund.fasta All_$k.OTU.ID.abund.fasta.nhmmer.blast All_$k.OTU.ID.hmm.fasta";


###
# Batch SAP
###
	print "10. Preparing for SAP $k\n";
	system "sap All_$k.OTU.ID.abund.fasta -d All_$k.OTU.ID.abund.fasta.sap --svg -e test\@gmail.com";
}

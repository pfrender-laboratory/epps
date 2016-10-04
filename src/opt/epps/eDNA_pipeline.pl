#!usr/bin/perl -w
use strict;
use FindBin qw($Bin $Script);
use File::Basename qw(basename dirname);
use Getopt::Long;
use Cwd;
#use Cwd 'abs_path';
#my $abs_path = abs_path($file);

=head1 Usage:
        perl eDNA_pipeline.pl -l [fq list] -o [output directory] -dm [Demultiplexing: Y/N] -pm [primer set] -p [output file prefix]

=head1 Version

	V3.9 08/12/2016 Modified demultiplexing script, only allowing 5bp before primer / -maxrejects 128 for usearch
	V3.8 05/17/2016 Leaving / Minor revision: change cat uc.* to cat uc.1 ... uc.10
	V3.7 05/04/2016 Ji / First committee meeting / HMMER only pick OTUs without fragmented hits
	V3.6 04/14/2016 Add LCOI HMMER model / Optimize the counting fq process
	V3.5 04/05/2016 Split reads to run mapping every time to get over the read-number limit of USEARCH -usearch_global to -db
	V3.4 03/30/2016 Add two kit scripts to the pipeline for basic stats and non-target sequence removal
	V3.3 12/07/2015 Add remove windows linebreak function during demultiplexing / Add log file for demultiplexing
	V3.2 10/22/2015 add usearch and nhmmer into the \$Bin directory / concatenate libraries automatically 
	V3.1 09/17/2015 Auto report
	V3.0 08/12/2015 batch model on all the samples / produce a new OTU clustering output (UParse format)

	V2.8 07/28/2015 add a batch_prep_kit.pl to batch mkdir and link raw reads / remove email notification
	V2.7 07/22/2015 change SAP script to 10 sequences per batch
	V2.6 06/29/2015 YY's written comp done! / rename sequences with sample ID
	V2.5 06/12/2015 automatic report output / bug fixed with demultiplexing script
	V2.4 05/08/2015 with option to run with customized primer set / using USEARCH v8.0.1623
	V2.3 04/22/2015 home made Dereplication handle
	V2.2 04/22/2015 with batch SAP assignment / remove length cutoff option
	V2.1 put adaptor removing step forward
	V2.0 add HMM model in post-clustering step, put adaptor moving before merging

	V1.5 add abundance information in OTU results and add length cutoffs in post-clustering step
	V1.4 add SAP into pipeline and remove sequences with \"N\" after overlap
	V1.3 gz format fastq file compatiable
	V1.2 can't remember the updates\n"
=cut

my ($list, $directory, $prefix, $primer, $demul, $array, $Help, $job_num);

GetOptions(
	"l:s"=>\$list,
	"o:s"=>\$directory,
	"p=s"=>\$prefix,
	"pm=s"=>\$primer,
	"dm=s"=>\$demul,
	"h"=>\$Help
	
);
die `pod2text $0` if ((not defined $list) || (not defined $directory) || (not defined $prefix) || $Help || (not defined $demul));

my $dir = getcwd;
$primer = $dir."/".$primer;
print "$primer\n";

die `pod2text $0` if ((not defined $list) || (not defined $directory) || (not defined $prefix) || $Help || (not defined $demul));

my %files;
if($demul eq "Y"){

	mkdir("$directory\/Samples") unless(-d "$directory\/Samples");

	open (LS, $list) or die "$list $!\n";
	while(<LS>){
		chomp;

		my $file_name;
		my $path = $_;
		my @line = split/\//, $path;
		my @id = split/\_/, $line[-1];
#		my @id = split/\./, $line[-1];

		$id[0] =~ s/\-/\_/;

		my $folder;
		if($prefix eq "NA"){
		        $file_name = $id[0];
		}else{
		        $file_name = $prefix.$id[0];
		}

		my $fq; 
		if($id[-2] eq "R1"){
#		if($id[-2] eq "1"){
		        $fq = 1;
		}else{ 
		        $fq = 2;
		}

		`ln -s $path $directory\/Samples\/$file_name.$fq.fq.gz`;
#		`ln -s $path $directory\/Samples\/$file_name.$fq.fq`;
		$file_name = "\"".$file_name."\"";
		$files{$file_name} = 1;
	}
	close LS;

	my @files = sort keys %files;
	$job_num = @files;
	$array = join ",", @files;

	open (JOB, ">$directory\/Samples\/batch_filter.sh") or die "batch_filter.sh $!\n";
	print JOB "\#\!/bin/csh

set Array = {$array};

\#\$ -N batch_filter.sh
\#\$ -t 1-$job_num:1
\#\$ -r y

perl $Bin/fq_status_V1.2.pl \${Array[\$SGE_TASK_ID]}.1.fq.gz \${Array[\$SGE_TASK_ID]}.2.fq.gz > \${Array[\$SGE_TASK_ID]}.fq.infor

# To remove sequencing adapters
java -jar $Bin/trimmomatic-0.32.jar PE -phred33 -trimlog trim.log \${Array[\$SGE_TASK_ID]}.1.fq.gz \${Array[\$SGE_TASK_ID]}.2.fq.gz \${Array[\$SGE_TASK_ID]}.1.pe.fq \${Array[\$SGE_TASK_ID]}.1.se.fq \${Array[\$SGE_TASK_ID]}.2.pe.fq \${Array[\$SGE_TASK_ID]}.2.se.fq ILLUMINACLIP:$Bin/primers/MiSeq.adapter.fas:3:30:6:1:true SLIDINGWINDOW:10:20 MINLEN:50;

# Demultiplex and remove primer (100% identical). Reads were re-orientated based on primer
perl $Bin/Demultiplex_primer_v1.4.pl \${Array[\$SGE_TASK_ID]}.1.pe.fq \${Array[\$SGE_TASK_ID]}.2.pe.fq $primer \${Array[\$SGE_TASK_ID]} \${Array[\$SGE_TASK_ID]}.demultiplex.infor;"

}else{
	print "Using demultiplexed data\n";
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

open (QSB, ">$directory\/Samples\/qsub.sh") or die "qsub.sh $!\n";

foreach my $k (keys %hash){
	print QSB "qsub batch_$k.sh\n";
	open (OUT, ">$directory\/Samples\/batch_$k.sh") or die "batch_$k.sh $!\n";

	print OUT "\#\!/bin/csh
set Array = {$array};

\#\$ -N batch_$k.sh
\#\$ -t 1-$job_num:1
\#\$ -r y

# To remove \"staggered\" overlaps & Merge paired-end reads
$Bin/usearch -fastq_mergepairs \${Array[\$SGE_TASK_ID]}_$k.F.fq -reverse \${Array[\$SGE_TASK_ID]}_$k.R.fq -fastqout \${Array[\$SGE_TASK_ID]}_$k.merged.fastq -fastq_allowmergestagger

# Quality filtering
$Bin/usearch -fastq_filter \${Array[\$SGE_TASK_ID]}_$k.merged.fastq -fastq_maxee 0.5 -fastaout \${Array[\$SGE_TASK_ID]}_$k.merged.fasta -fastq_maxns 1

# Send to Report
perl /afs/crc.nd.edu/group/pfrenderlab/kimura/yli19/bin/shortcuts/fq_status_V1.1.pl \${Array[\$SGE_TASK_ID]}_$k.F.fq \${Array[\$SGE_TASK_ID]}_$k.R.fq \${Array[\$SGE_TASK_ID]}_$k.merged.fastq > \${Array[\$SGE_TASK_ID]}_$k.report

# Rename fasta for dereplication
perl $Bin/rename_4.0.pl \${Array[\$SGE_TASK_ID]}_$k.merged.fasta \${Array[\$SGE_TASK_ID]}  \${Array[\$SGE_TASK_ID]}_$k.rename.fas
";

	close OUT;

open (CMB, ">$directory\/All_$k.sh") or die "All_$k.sh $!\n";
print CMB "\#\!/bin/csh
\#\$ -M yli19\@nd.edu
\#\$ -m abe
\#\$ -pe smp 8
\#\$ -q long
\#\$ -N All_$k.sh

cat ./Samples/*_$k.rename.fas > All_$k.rename.fas
# Dereplication
perl $Bin/unique.pl All_$k.rename.fas All_$k.rename.unique.fas
$Bin/usearch -sortbysize All_$k.rename.unique.fas -fastaout All_$k.rename.unique.sorted.fasta -minsize 2

# OTU clustering
$Bin/usearch -cluster_otus All_$k.rename.unique.sorted.fasta -otus All_$k.OTU.fasta -sizein -sizeout -uparseout All_$k.OTU.fasta.up
$Bin/usearch -sortbysize All_$k.OTU.fasta -fastaout All_$k.OTU.sorted.fasta

# count OTU size
perl $Bin/rename_4.0.pl All_$k.OTU.sorted.fasta OTU  All_$k.OTU.ID.fasta

perl $Bin/split_fasta.pl All_$k.rename.fas 10 All_$k.rename.split
$Bin/usearch -usearch_global All_$k.rename.split.1.fas  -db All_$k.OTU.ID.fasta -strand plus -id 0.97 -uc All_$k.OTU.ID.uc.1 -maxrejects 128
$Bin/usearch -usearch_global All_$k.rename.split.2.fas  -db All_$k.OTU.ID.fasta -strand plus -id 0.97 -uc All_$k.OTU.ID.uc.2 -maxrejects 128
$Bin/usearch -usearch_global All_$k.rename.split.3.fas  -db All_$k.OTU.ID.fasta -strand plus -id 0.97 -uc All_$k.OTU.ID.uc.3 -maxrejects 128
$Bin/usearch -usearch_global All_$k.rename.split.4.fas  -db All_$k.OTU.ID.fasta -strand plus -id 0.97 -uc All_$k.OTU.ID.uc.4 -maxrejects 128
$Bin/usearch -usearch_global All_$k.rename.split.5.fas  -db All_$k.OTU.ID.fasta -strand plus -id 0.97 -uc All_$k.OTU.ID.uc.5 -maxrejects 128
$Bin/usearch -usearch_global All_$k.rename.split.6.fas  -db All_$k.OTU.ID.fasta -strand plus -id 0.97 -uc All_$k.OTU.ID.uc.6 -maxrejects 128
$Bin/usearch -usearch_global All_$k.rename.split.7.fas  -db All_$k.OTU.ID.fasta -strand plus -id 0.97 -uc All_$k.OTU.ID.uc.7 -maxrejects 128
$Bin/usearch -usearch_global All_$k.rename.split.8.fas  -db All_$k.OTU.ID.fasta -strand plus -id 0.97 -uc All_$k.OTU.ID.uc.8 -maxrejects 128
$Bin/usearch -usearch_global All_$k.rename.split.9.fas  -db All_$k.OTU.ID.fasta -strand plus -id 0.97 -uc All_$k.OTU.ID.uc.9 -maxrejects 128
$Bin/usearch -usearch_global All_$k.rename.split.10.fas  -db All_$k.OTU.ID.fasta -strand plus -id 0.97 -uc All_$k.OTU.ID.uc.10 -maxrejects 128
cat All_$k.OTU.ID.uc.1 All_$k.OTU.ID.uc.2 All_$k.OTU.ID.uc.3 All_$k.OTU.ID.uc.4 All_$k.OTU.ID.uc.5 All_$k.OTU.ID.uc.6 All_$k.OTU.ID.uc.7 All_$k.OTU.ID.uc.8 All_$k.OTU.ID.uc.9 All_$k.OTU.ID.uc.10 > All_$k.OTU.ID.uc

#$Bin/usearch -usearch_global All_$k.rename.fas -db All_$k.OTU.ID.fasta -strand plus -id 0.97 -uc All_$k.OTU.ID.uc

less -S All_$k.OTU.ID.uc| perl -e \'while(<>){\@s=split; if(\$s[-1] eq \"\*\"){}else{\$hash{\$s[-1]} ++;} } foreach my \$k (sort {\$hash{\$b}<=>\$hash{\$a}} keys %hash){ print \"\$k\\t\$hash{\$k}\\n\"; }\' > All_$k.OTU.ID.uc.summary

perl $Bin/add_abundance.pl All_$k.OTU.ID.fasta All_$k.OTU.ID.uc.summary NA All_$k.OTU.ID.abund.fasta


###
# HMMer
###
$Bin/nhmmer --tblout All_$k.OTU.ID.abund.fasta.nhmmer.blast -o All_$k.OTU.ID.abund.fasta.nhmmer -E 1e-10 $Bin/hmm/$k\_DB.rename.aln.hmm All_$k.OTU.ID.abund.fasta
perl $Bin/pick_sequences_on_hmmer_list.pl All_$k.OTU.ID.abund.fasta All_$k.OTU.ID.abund.fasta.nhmmer.blast All_$k.OTU.ID.hmm.fasta


###
# Batch SAP
###
perl $Bin/split_sap.pl All_$k.OTU.ID.abund.fasta 10 All_$k
";
	close CMB;

###
# Print report
###
open (RPT, ">$directory\/Report.sh") or die "Report.sh $!\n";
print RPT "perl $Bin/report.pl fq.infor all.report";

}

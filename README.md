# epps
This is for running the eDNA pipeline (epps) in the pfrender lab. It takes a fastq list and a primer set and automatically does quality filtering, gene demultiplexing, merging, clustering and speices assignment. 

Usage:
perl eDNA_pipeline.pl -l [fq list] -o [output directory] -pm [primer set] -p [output file prefix]

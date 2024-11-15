# BPNet Snakemake 

Snakemake pipeline that runs by [BPNet](https://github.com/kundajelab/basepairmodels) pipeline:
1. prepares input files (merge bams, convert into bigWig files)
2. Run BPNet pipeline using GPU
	- train BPNet model  
	- calculate shape score
	- generate bigWig file for shape score
	- run TF-modisco to see important motifs within peak


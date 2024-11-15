### prepare file snakemake
configfile: "prepare_input.yaml"

EXPERIMENTS = config["experiments"]
chrsize = config["chrsize"]
bam_dir = config["dir"]

rule all:
  input:
    expand("bw/{exp}.minus.bw", exp=list(EXPERIMENTS.keys()))

# merge bams
rule merge_bams:
  input:
    bams = lambda wildcards: [f"{bam_dir}/{fid}.bam" for fid in config["experiments"][wildcards.exp]["replicates"]]
  output:
    "merged/{exp}_merged.bam"
  threads: config["params"]["samtools"]["threads"]
  shell:
    """
    samtools merge -@ {threads} -f {output} {input.bams}
    """

# index merged_bam
rule samtools_index:
  input:
    "merged/{exp}_merged.bam"
  output:
    "merged/{exp}_merged.bam.bai"
  shell:
    "samtools index {input}"

# get coverage of 5' positions of the plus&minus strand
rule bam_to_stranded_bedGraph:
  input:
    bam="merged/{exp}_merged.bam",
    index="merged/{exp}_merged.bam.bai"
  output:
    plus="{exp}.plus.bedGraph",
    minus="{exp}.minus.bedGraph"
  shell:
    """
    bedtools genomecov -5 -bg -strand + -ibam {input.bam} \
          | sort -k1,1 -k2,2n > {output.plus}
    bedtools genomecov -5 -bg -strand - -ibam {input.bam} \
          | sort -k1,1 -k2,2n > {output.minus}
    """

# bedGraph to bigWig
rule bdg_to_bw:
  input:
    plus="{exp}.plus.bedGraph",
    minus="{exp}.minus.bedGraph"
  output:
    plus="bw/{exp}.plus.bw",
    minus="bw/{exp}.minus.bw"
  shell:
    """
    bedGraphToBigWig {input.plus} {chrsize} {output.plus}
    bedGraphToBigWig {input.minus} {chrsize} {output.minus}
    """


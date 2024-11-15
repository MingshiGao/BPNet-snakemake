configfile: "config.yaml"
EXPERIMENTS = config["experiments"]
refDir = config["refDir"]

rule all:
  input:
    expand("{exp}/modisco_profile/modisco_results.h5", exp=list(EXPERIMENTS.keys()))


### generate exp input data json
rule input_json:
  output:
    "{exp}/input_data.json"  # {exp} is the experiment identifier
  params:
    control_exp=lambda wildcards: EXPERIMENTS[wildcards.exp]["control_exp"]
  shell:
    """
    mkdir -p {wildcards.exp}
    sed -e "s/exp/{wildcards.exp}/" -e "s/control/{params.control_exp}.control/" input_data.json > {output}
    """

### generate exp params json
rule params_json:
  input:
    "{exp}/input_data.json"
  output:
    "{exp}/bpnet_params.json"
  shell:
    """
    weight=$(counts_loss_weight --input-data {input})
    sed "s/42/$weight/" bpnet_params.json > {output}
    """

### train BPNet model
rule BPNet:
  input:
    input_data="{exp}/input_data.json",
    model_prams="{exp}/bpnet_params.json"
  output:
    "{exp}/models/model_split000.h5"
  params:
    dir="{mainDir}/{exp}"
  shell:
    """
    rm -rf {params.dir}/models
    mkdir -p {params.dir}/models
    train \
        --input-data {input.input_data} \
        --output-dir {params.dir}/models \
        --reference-genome {refDir}/hg38.fa \
        --chroms $(paste -s -d ' ' {refDir}/hg38_chroms.txt) \
        --chrom-sizes {refDir}/hg38.chrom.sizes \
        --splits splits.json \
        --model-arch-name BPNet \
        --model-arch-params-json {input.model_prams} \
        --sequence-generator-name BPNet \
        --model-output-filename model \
        --input-seq-len 2114 \
        --output-len 1000 \
        --shuffle \
        --threads 10 \
        --epochs 100 \
        --learning-rate 0.004
    """

### generate shape score
rule shap_score:
  input:
    model="{exp}/models/model_split000.h5",
    peak="data/peak/{exp}.bed"
  output:
    "{exp}/shap/profile_scores.h5"
  params:
    dir="{mainDir}/{exp}"
  shell:
    """
    rm -rf {params.dir}/shap
    mkdir -p {params.dir}/shap
    shap_scores \
        --reference-genome {refDir}/hg38.fa \
        --model {input.model}  \
        --bed-file {input.peak} \
        --chroms $(paste -s -d ' ' {refDir}/hg38_chroms.txt) \
        --output-dir {params.dir}/shap \
        --input-seq-len 2114 \
        --control-len 1000 \
        --task-id 0 \
        --input-data {params.dir}/input_data.json
    """

### shape score bigWig
rule shap_bw:
  input:
    shap="{exp}/shap/profile_scores.h5",
    peak="{exp}/shap/peaks_valid_scores.bed"
  output:
    "{exp}/shap/{exp}.shap_score.bw"
  shell:
    """
    python h5_to_bw.py {input.shap} {input.peak} {refDir}/hg38.chrom.sizes shap_score.bw
    awk 'BEGIN{OFS="\t"} {if(ARGIND==1){c[NR]=$1;s[NR]=$11}else{for(i=1;i<=2114;i++){print c[FNR],s[FNR]+i-1,s[FNR]+i,$i}}}' peaks_valid_scores.bed tmp > tmp.bdg
    sort -k1,1 -k2,2n tmp.bdg > tmp
    awk '!a[$1$2$3]++' tmp > tmp.sort.bdg
    bedGraphToBigWig tmp.sort.bdg {refDir}/hg38.chrom.sizes {output}
    rm tmp *bdg
    """

### train TF-Modisco
rule modisco:
  input:
    "{exp}/shap/profile_scores.h5"
  output:
    "{exp}/modisco_profile/modisco_results.h5"
  params:
    dir="{exp}"
  shell:
    """
    rm -rf {params.dir}/modisco_profile
    mkdir {params.dir}/modisco_profile
    motif_discovery \
    	    --scores-path {input} \
    	    --output-directory {params.dir}/modisco_profile
    """



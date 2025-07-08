#!/usr/bin/sh
#SBATCH -A MST109178        # Account name/project number
#SBATCH -J vep        # Job name
#SBATCH -p ngs53G           # Partition Name 等同PBS裡面的 -q Queue name
#SBATCH -c 8               # 使用的core數 請參考Queue資源設定 
#SBATCH --mem=53g           # 使用的記憶體量 請參考Queue資源設定
#SBATCH --mail-user=
#SBATCH --mail-type=

# Path of VEP
VEP_CACHE_DIR=/opt/ohpc/Taiwania3/pkg/biology/DATABASE/VEP/Cache
VEP_FASTA=/staging/reserve/paylong_ntu/AI_SHARE/reference/VEP/Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz


data=/staging/reserve/jacobhsu/TWB
# Files for custom annotation
ref_dir=${data}/TWB_1490/VEP_custom_database
twb_del=${ref_dir}/TWB1480_hs38DH_del.vcf.gz
twb_ins=${ref_dir}/TWB1480_hs38DH_ins.vcf.gz
twb_small=${ref_dir}/TWB1490_hg38_IGG_jc_split_multiallelic.vcf.gz

database=/staging/biology/r12455009/del_ins_snv_vcf_merge/VEP_annotation/database
gnomaddel=${database}/DEL_gnomad.v4.1.non_neuro.vcf.gz
gnomadins=${database}/INS_gnomad.v4.1.non_neuro.vcf.gz
clinvardel=${database}/clinvar/clinvar_20241230_del.vcf.gz
clinvarins=${database}/clinvar/clinvar_20241230_ins.vcf.gz
clinvardel_p=${database}/clinvar/clinvar_20241230_deletion_p_lp.vcf.gz
clinvardel_b=${database}/clinvar/clinvar_20241230_deletion_b_lb.vcf.gz
ccre=${database}/functional_region/encode_ucsc_regulatory.bed.gz


# file name & output path setting
SAMPLE=TWB1480_hs38DH_del
SAMPLE_ID=${SAMPLE}_gnomAD_dist200
INPUT_VCF_PATH=${data}/TWB_1490/${SAMPLE}_addinfo.vcf.gz
OUTPUT_VCF_PATH=${data}/TWB_1482_SV/VEP/v112/pick/diff_parameter/DEL
mkdir -p $OUTPUT_VCF_PATH

cd $OUTPUT_VCF_PATH


# load environment
ml pkg/Anaconda3
conda activate /opt/ohpc/Taiwania3/pkg/biology/vep/vep_v112.0
set -euo pipefail


# Log file settings
TIME=`date +%Y%m%d%H%M`
logfile=/staging/reserve/jacobhsu/TWB/TWB_1482_SV/log/${TIME}_run_vep_${SAMPLE_ID}.log

# Redirect standard output and error to the log file
exec > "$logfile" 2>&1

echo "$(date '+%Y-%m-%d %H:%M:%S') Job started" >> ${logfile}

# custom annotation
## TWB
custom_snv_indel="file=${twb_small},short_name=TWB1490_SNV_indel,format=vcf,fields=AF,type=exact"
custom_del="file=${twb_del},short_name=TWB1480_DEL,format=vcf,fields=FILTER%AF,type=overlap,distance=200"
custom_ins="file=${twb_ins},short_name=TWB1480_INS,format=vcf,fields=FILTER%AF,type=overlap,distance=200"

## gnomAD
field="FILTER%AF%GRPMAX_AF%AF_eas%AF_non_neuro%AF_non_neuro_eas%AF_controls_and_biobanks%AF_controls_and_biobanks_eas"
gnomad_del="file=${gnomaddel},short_name=gnomAD_v4.1_dist200,format=vcf,fields=${field},type=overlap,distance=200"
gnomad_ins="file=${gnomadins},short_name=gnomAD_v4.1_dist200,format=vcf,fields=${field},type=overlap,distance=200"

## ClinVar
clinvar_del="file=${clinvardel},short_name=ClinVar,format=vcf,fields=CLNSIG%CLNREVSTAT%MC%CLNDN,type=exact"
clinvar_ins="file=${clinvarins},short_name=ClinVar,format=vcf,fields=CLNSIG%CLNREVSTAT%MC%CLNDN,type=exact"
clinvar_del_p="file=${clinvardel_p},short_name=ClinVar_p_lp,format=vcf,fields=CLNSIG%CLNREVSTAT%MC%CLNDN,type=within"
clinvar_del_b="file=${clinvardel_b},short_name=ClinVar_b_lb,format=vcf,fields=CLNSIG%CLNREVSTAT%MC%CLNDN,type=surrounding"

## ENCODE cCREs
func_impact="file=${ccre},short_name=ENCODE_cCREs,format=bed,type=surrounding"


# Run VEP
## Add `--custom $file` based on the data you want to annotate.
vep --cache --offline \
    -i $INPUT_VCF_PATH \
    --format vcf \
    --fork 4 \
    --check_existing \
    --force_overwrite \
    --dir_cache $VEP_CACHE_DIR \
    --assembly GRCh38 \
    --overlaps \
    --pick \
    --custom ${gnomad_del} \
    --no_stats \
    --fasta $VEP_FASTA \
    --vcf \
    -o VEP_${SAMPLE_ID}.vcf


# generate tsv
echo -e "CHROM\tPOS\tREF\tALT\tFILTER\t$(bcftools +split-vep -l VEP_${SAMPLE_ID}.vcf | cut -f 2 | tr '\n' '\t' | sed 's/\t$//')" > VEP_${SAMPLE_ID}.tsv
bcftools +split-vep -f '%CHROM\t%POS\t%REF\t%ALT\t%FILTER\t%CSQ\n' -d -A tab VEP_${SAMPLE_ID}.vcf >> VEP_${SAMPLE_ID}.tsv

echo "$(date '+%Y-%m-%d %H:%M:%S') Job finished" >> ${logfile}


./nextflow run nf-core/viralrecon -r 2.5 \
    --max_cpus 30 \
    --max_memory '120.GB' \
    --input input.csv \
    --outdir output_mpox_test \
    --platform illumina \
    --protocol amplicon \
    --fasta ~/references/idt_ref_mpox.fasta \
    --kraken2_db ~/references/kraken2-human-db \
    --save_reference false \
    --variant_caller 'ivar' \
    --primer_bed ~/references/MPX_primers_220908_edit.bed \
    --primer_left_suffix "_FOR" \
    --primer_right_suffix "_REV" \
    --ivar_trim_offset 5 \
    --skip_assembly \
    --skip_nextclade \
    -profile docker \
    -with-docker nfcore/virarecon
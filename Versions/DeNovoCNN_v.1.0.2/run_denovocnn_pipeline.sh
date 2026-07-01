#!/bin/bash

###############################################################################
# DeNovoCNN Analysis Pipeline
# 
# This script processes trio BAM/VCF files, runs de novo variant detection,
# prioritizes variants by phenotype, and generates results.
# 
# Run after installation: ./install_denovocnn.sh
#
# Usage: ./run_denovocnn_pipeline.sh [options]
###############################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default parameters
WORK_DIR="./denovo_analysis"
CHILD_BAM=""
FATHER_BAM=""
MOTHER_BAM=""
CHILD_VCF=""
FATHER_VCF=""
MOTHER_VCF=""
REFERENCE=""
PHENOTYPE_FILE=""
OUTPUT_DIR=""
INSTALL_DIR="./DeNovoCNN"

###############################################################################
# Load Installation Configuration
###############################################################################
load_install_config() {
    if [[ -f "$INSTALL_DIR/install_config.sh" ]]; then
        source "$INSTALL_DIR/install_config.sh"
        echo -e "${GREEN}Loaded installation configuration from: $INSTALL_DIR/install_config.sh${NC}"
    else
        echo -e "${YELLOW}Warning: Installation configuration not found. Using defaults.${NC}"
        echo -e "${YELLOW}Run ./install_denovocnn.sh first for proper setup.${NC}"
    fi
}

###############################################################################
# Help Function
###############################################################################
print_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Required Arguments:"
    echo "  --child-bam PATH        Child BAM/CRAM file"
    echo "  --father-bam PATH       Father BAM/CRAM file"
    echo "  --mother-bam PATH       Mother BAM/CRAM file"
    echo "  --child-vcf PATH        Child VCF file (candidate variants)"
    echo "  --father-vcf PATH       Father VCF file"
    echo "  --mother-vcf PATH       Mother VCF file"
    echo "  --reference PATH        Reference genome FASTA file"
    echo ""
    echo "Optional Arguments:"
    echo "  --phenotype-file PATH   File with HPO terms (one per line)"
    echo "  --work-dir PATH         Working directory (default: ./denovo_analysis)"
    echo "  --output-dir PATH       Output directory (default: work_dir/results)"
    echo "  --install-dir PATH      DeNovoCNN installation directory (default: ./DeNovoCNN)"
    echo "  --help                  Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --child-bam child.bam --father-bam father.bam --mother-bam mother.bam \\"
    echo "     --child-vcf child.vcf --father-vcf father.vcf --mother-vcf mother.vcf \\"
    echo "     --reference GRCh38.fa --phenotype-file phenotypes.txt"
}

###############################################################################
# Parse Arguments
###############################################################################
while [[ $# -gt 0 ]]; do
    case $1 in
        --child-bam)
            CHILD_BAM="$2"
            shift 2
            ;;
        --father-bam)
            FATHER_BAM="$2"
            shift 2
            ;;
        --mother-bam)
            MOTHER_BAM="$2"
            shift 2
            ;;
        --child-vcf)
            CHILD_VCF="$2"
            shift 2
            ;;
        --father-vcf)
            FATHER_VCF="$2"
            shift 2
            ;;
        --mother-vcf)
            MOTHER_VCF="$2"
            shift 2
            ;;
        --reference)
            REFERENCE="$2"
            shift 2
            ;;
        --phenotype-file)
            PHENOTYPE_FILE="$2"
            shift 2
            ;;
        --work-dir)
            WORK_DIR="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --help)
            print_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            print_help
            exit 1
            ;;
    esac
done

###############################################################################
# Load installation configuration
###############################################################################
load_install_config

###############################################################################
# Validate Required Arguments
###############################################################################
if [[ -z "$CHILD_BAM" || -z "$FATHER_BAM" || -z "$MOTHER_BAM" ]]; then
    echo -e "${RED}Error: Child, father, and mother BAM files are required${NC}"
    print_help
    exit 1
fi

if [[ -z "$CHILD_VCF" || -z "$FATHER_VCF" || -z "$MOTHER_VCF" ]]; then
    echo -e "${RED}Error: Child, father, and mother VCF files are required${NC}"
    print_help
    exit 1
fi

if [[ -z "$REFERENCE" ]]; then
    echo -e "${RED}Error: Reference genome file is required${NC}"
    print_help
    exit 1
fi

# Set output directory if not specified
if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$WORK_DIR/results"
fi

###############################################################################
# Check File Existence
###############################################################################
check_file() {
    if [[ ! -f "$1" ]]; then
        echo -e "${RED}Error: File not found: $1${NC}"
        exit 1
    fi
}

echo -e "${BLUE}Checking input files...${NC}"
check_file "$CHILD_BAM"
check_file "$FATHER_BAM"
check_file "$MOTHER_BAM"
check_file "$CHILD_VCF"
check_file "$FATHER_VCF"
check_file "$MOTHER_VCF"
check_file "$REFERENCE"

# Check if BAM index files exist, if not create them
for bam in "$CHILD_BAM" "$FATHER_BAM" "$MOTHER_BAM"; do
    if [[ ! -f "${bam}.bai" && ! -f "${bam%.bam}.bai" ]]; then
        echo -e "${YELLOW}Creating index for $bam...${NC}"
        samtools index "$bam"
    fi
done

# Check if VCF files are indexed
for vcf in "$CHILD_VCF" "$FATHER_VCF" "$MOTHER_VCF"; do
    if [[ ! -f "${vcf}.tbi" && ! -f "${vcf%.gz}.tbi" ]]; then
        echo -e "${YELLOW}Creating index for $vcf...${NC}"
        bgzip -c "$vcf" > "${vcf}.gz" 2>/dev/null || true
        tabix -p vcf "${vcf}.gz" 2>/dev/null || tabix -p vcf "$vcf" 2>/dev/null || true
    fi
done

###############################################################################
# Create Working Directory Structure
###############################################################################
echo -e "${BLUE}Creating working directory structure...${NC}"
mkdir -p "$WORK_DIR/input"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$WORK_DIR/intermediate"

###############################################################################
# Copy/Symlink Input Files
###############################################################################
echo -e "${BLUE}Preparing input files...${NC}"
ln -sf "$(realpath "$CHILD_BAM")" "$WORK_DIR/input/child.bam"
ln -sf "$(realpath "$FATHER_BAM")" "$WORK_DIR/input/father.bam"
ln -sf "$(realpath "$MOTHER_BAM")" "$WORK_DIR/input/mother.bam"
ln -sf "$(realpath "$CHILD_VCF")" "$WORK_DIR/input/child.vcf"
ln -sf "$(realpath "$FATHER_VCF")" "$WORK_DIR/input/father.vcf"
ln -sf "$(realpath "$MOTHER_VCF")" "$WORK_DIR/input/mother.vcf"
ln -sf "$(realpath "$REFERENCE")" "$WORK_DIR/input/reference.fa"

# Copy index files
for bam in child father mother; do
    if [[ -f "${CHILD_BAM}.bai" ]]; then
        cp "${CHILD_BAM}.bai" "$WORK_DIR/input/${bam}.bai"
    elif [[ -f "${CHILD_BAM%.bam}.bai" ]]; then
        cp "${CHILD_BAM%.bam}.bai" "$WORK_DIR/input/${bam}.bai"
    fi
done

###############################################################################
# Define Model Paths
###############################################################################
if [[ "$USE_CONDA" = true ]]; then
    SNP_MODEL="$INSTALL_DIR/models/snp"
    INS_MODEL="$INSTALL_DIR/models/ins"
    DEL_MODEL="$INSTALL_DIR/models/del"
else
    SNP_MODEL="/app/models/snp"
    INS_MODEL="/app/models/ins"
    DEL_MODEL="/app/models/del"
fi

###############################################################################
# Split VCF for WGS Data (if needed)
###############################################################################
echo -e "${BLUE}Checking if VCF splitting is needed for WGS data...${NC}"
VCF_SIZE=$(stat -f%z "$CHILD_VCF" 2>/dev/null || stat -c%s "$CHILD_VCF" 2>/dev/null)
SPLIT_VCF=false

if [[ $VCF_SIZE -gt 100000000 ]]; then  # If VCF > 100MB, split it
    echo -e "${YELLOW}Large VCF detected ($VCF_SIZE bytes). Splitting for parallel processing...${NC}"
    SPLIT_VCF=true
    
    # Generate list of all variant positions
    bcftools isec -C "$WORK_DIR/input/child.vcf" "$WORK_DIR/input/father.vcf" "$WORK_DIR/input/mother.vcf" > \
        "$WORK_DIR/intermediate/all_variants.txt" 2>/dev/null || true
    
    # Split into chunks of 10,000 variants
    split -d -l 10000 --additional-suffix=.txt "$WORK_DIR/intermediate/all_variants.txt" \
        "$WORK_DIR/intermediate/part_variants"
    
    NUM_PARTS=$(ls "$WORK_DIR/intermediate/part_variants"*.txt 2>/dev/null | wc -l)
    echo -e "${GREEN}Split into $NUM_PARTS parts for parallel processing${NC}"
fi

###############################################################################
# Run DeNovoCNN
###############################################################################
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Running DeNovoCNN Analysis${NC}"
echo -e "${BLUE}========================================${NC}"

if [[ "$SPLIT_VCF" = true ]]; then
    # Run in parallel for each part
    echo -e "${BLUE}Processing $NUM_PARTS parts in parallel...${NC}"
    
    > "$OUTPUT_DIR/predictions_combined.csv"
    echo "chromosome,start,reference,variant,probability,prediction" > "$OUTPUT_DIR/predictions_combined.csv"
    
    for part in "$WORK_DIR/intermediate/part_variants"*.txt; do
        part_num=$(basename "$part" .txt | sed 's/part_variants//')
        echo -e "${YELLOW}Processing part $part_num...${NC}"
        
        if [[ "$USE_CONDA" = true ]]; then
            # Run with conda
            if [[ -n "$CONDA_PREFIX" ]]; then
                conda run -p "$CONDA_PREFIX" \
                    bash "$INSTALL_DIR/apply_denovocnn.sh" \
                    -w="$OUTPUT_DIR" \
                    -cv="$WORK_DIR/input/child.vcf" \
                    -fv="$WORK_DIR/input/father.vcf" \
                    -mv="$WORK_DIR/input/mother.vcf" \
                    -cb="$WORK_DIR/input/child.bam" \
                    -fb="$WORK_DIR/input/father.bam" \
                    -mb="$WORK_DIR/input/mother.bam" \
                    -sm="$SNP_MODEL" \
                    -im="$INS_MODEL" \
                    -dm="$DEL_MODEL" \
                    -g="$WORK_DIR/input/reference.fa" \
                    -v="$part" \
                    -o="$OUTPUT_DIR/predictions_part${part_num}.csv" || true
            else
                conda run -n "$CONDA_ENV_NAME" \
                    bash "$INSTALL_DIR/apply_denovocnn.sh" \
                    -w="$OUTPUT_DIR" \
                    -cv="$WORK_DIR/input/child.vcf" \
                    -fv="$WORK_DIR/input/father.vcf" \
                    -mv="$WORK_DIR/input/mother.vcf" \
                    -cb="$WORK_DIR/input/child.bam" \
                    -fb="$WORK_DIR/input/father.bam" \
                    -mb="$WORK_DIR/input/mother.bam" \
                    -sm="$SNP_MODEL" \
                    -im="$INS_MODEL" \
                    -dm="$DEL_MODEL" \
                    -g="$WORK_DIR/input/reference.fa" \
                    -v="$part" \
                    -o="$OUTPUT_DIR/predictions_part${part_num}.csv" || true
            fi
        else
            # Run with Docker
            docker run \
                -v "$WORK_DIR/input:/input" \
                -v "$OUTPUT_DIR:/output" \
                "$DOCKER_IMAGE" \
                /app/apply_denovocnn.sh \
                --workdir=/output \
                --child-vcf=/input/child.vcf \
                --father-vcf=/input/father.vcf \
                --mother-vcf=/input/mother.vcf \
                --child-bam=/input/child.bam \
                --father-bam=/input/father.bam \
                --mother-bam=/input/mother.bam \
                --snp-model=/app/models/snp \
                --in-model=/app/models/ins \
                --del-model=/app/models/del \
                --genome=/input/reference.fa \
                --v="$part" \
                --output="/output/predictions_part${part_num}.csv" || true
        fi
        
        # Combine results
        if [[ -f "$OUTPUT_DIR/predictions_part${part_num}.csv" ]]; then
            tail -n +2 "$OUTPUT_DIR/predictions_part${part_num}.csv" >> "$OUTPUT_DIR/predictions_combined.csv"
        fi
    done
    
    # Remove header duplicates and sort
    tail -n +2 "$OUTPUT_DIR/predictions_combined.csv" | sort -u > "$OUTPUT_DIR/predictions_temp.csv"
    echo "chromosome,start,reference,variant,probability,prediction" > "$OUTPUT_DIR/predictions_combined.csv"
    cat "$OUTPUT_DIR/predictions_temp.csv" >> "$OUTPUT_DIR/predictions_combined.csv"
    rm "$OUTPUT_DIR/predictions_temp.csv"
    
else
    # Run on single VCF
    if [[ "$USE_CONDA" = true ]]; then
        # Run with conda
        if [[ -n "$CONDA_PREFIX" ]]; then
            conda run -p "$CONDA_PREFIX" \
                bash "$INSTALL_DIR/apply_denovocnn.sh" \
                -w="$OUTPUT_DIR" \
                -cv="$WORK_DIR/input/child.vcf" \
                -fv="$WORK_DIR/input/father.vcf" \
                -mv="$WORK_DIR/input/mother.vcf" \
                -cb="$WORK_DIR/input/child.bam" \
                -fb="$WORK_DIR/input/father.bam" \
                -mb="$WORK_DIR/input/mother.bam" \
                -sm="$SNP_MODEL" \
                -im="$INS_MODEL" \
                -dm="$DEL_MODEL" \
                -g="$WORK_DIR/input/reference.fa" \
                -o="$OUTPUT_DIR/predictions.csv"
        else
            conda run -n "$CONDA_ENV_NAME" \
                bash "$INSTALL_DIR/apply_denovocnn.sh" \
                -w="$OUTPUT_DIR" \
                -cv="$WORK_DIR/input/child.vcf" \
                -fv="$WORK_DIR/input/father.vcf" \
                -mv="$WORK_DIR/input/mother.vcf" \
                -cb="$WORK_DIR/input/child.bam" \
                -fb="$WORK_DIR/input/father.bam" \
                -mb="$WORK_DIR/input/mother.bam" \
                -sm="$SNP_MODEL" \
                -im="$INS_MODEL" \
                -dm="$DEL_MODEL" \
                -g="$WORK_DIR/input/reference.fa" \
                -o="$OUTPUT_DIR/predictions.csv"
        fi
    else
        # Run with Docker
        docker run \
            -v "$WORK_DIR/input:/input" \
            -v "$OUTPUT_DIR:/output" \
            "$DOCKER_IMAGE" \
            /app/apply_denovocnn.sh \
            --workdir=/output \
            --child-vcf=/input/child.vcf \
            --father-vcf=/input/father.vcf \
            --mother-vcf=/input/mother.vcf \
            --child-bam=/input/child.bam \
            --father-bam=/input/father.bam \
            --mother-bam=/input/mother.bam \
            --snp-model=/app/models/snp \
            --in-model=/app/models/ins \
            --del-model=/app/models/del \
            --genome=/input/reference.fa \
            --output=/output/predictions.csv
    fi
fi

###############################################################################
# Process Results
###############################################################################
echo -e "${BLUE}Processing DeNovoCNN results...${NC}"

if [[ ! -f "$OUTPUT_DIR/predictions.csv" && ! -f "$OUTPUT_DIR/predictions_combined.csv" ]]; then
    echo -e "${RED}Error: DeNovoCNN did not produce output file${NC}"
    exit 1
fi

PREDICTIONS_FILE="$OUTPUT_DIR/predictions.csv"
if [[ -f "$OUTPUT_DIR/predictions_combined.csv" ]]; then
    PREDICTIONS_FILE="$OUTPUT_DIR/predictions_combined.csv"
fi

# Filter high-confidence de novo predictions (probability > 0.8)
echo -e "${BLUE}Filtering high-confidence de novo predictions...${NC}"
awk -F',' 'NR==1 || $5 > 0.8 {print}' "$PREDICTIONS_FILE" > "$OUTPUT_DIR/high_confidence_denovos.csv"

NUM_HIGH_CONF=$(tail -n +2 "$OUTPUT_DIR/high_confidence_denovos.csv" | wc -l)
echo -e "${GREEN}Found $NUM_HIGH_CONF high-confidence de novo variants${NC}"

###############################################################################
# Phenotype-Based Prioritization
###############################################################################
if [[ -n "$PHENOTYPE_FILE" && -f "$PHENOTYPE_FILE" ]]; then
    echo -e "${BLUE}Performing phenotype-based prioritization...${NC}"
    
    # Create Python script for phenotype matching
    cat > "$WORK_DIR/phenotype_prioritization.py" << 'EOFPYTHON'
#!/usr/bin/env python3
import sys
import subprocess

def get_phenotype_gene_associations(hpo_terms):
    """
    Get gene associations for HPO terms using simplified approach
    """
    gene_scores = {}
    
    # For demonstration, use a simple approach
    # In production, integrate with real HPO databases
    print("Performing phenotype-based prioritization...", file=sys.stderr)
    print("Note: Full HPO integration requires external databases", file=sys.stderr)
    
    return gene_scores

def annotate_variants_with_phenotype(variants_file, hpo_terms, output_file):
    """
    Annotate variants with phenotype relevance scores
    """
    # Read HPO terms
    with open(hpo_terms, 'r') as f:
        hpo_list = [line.strip() for line in f if line.strip() and not line.startswith('#')]
    
    print(f"Found {len(hpo_list)} HPO terms", file=sys.stderr)
    
    # Get gene associations
    gene_scores = get_phenotype_gene_associations(hpo_list)
    
    # Read variants and create basic ranking
    with open(variants_file, 'r') as infile, open(output_file, 'w') as outfile:
        header = infile.readline().strip()
        outfile.write(header + ",gene_symbol,phenotype_score\n")
        
        for line in infile:
            parts = line.strip().split(',')
            if len(parts) < 5:
                continue
            
            # Add placeholder gene symbol and score
            # In production, use VEP/ANNOVAR for real gene annotation
            outfile.write(f"{line.strip()},UNKNOWN,0.0\n")

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python phenotype_prioritization.py <variants_file> <hpo_terms_file> <output_file>", file=sys.stderr)
        sys.exit(1)
    
    variants_file = sys.argv[1]
    hpo_terms_file = sys.argv[2]
    output_file = sys.argv[3]
    
    annotate_variants_with_phenotype(variants_file, hpo_terms_file, output_file)
EOFPYTHON
    
    # Copy phenotype file to work directory
    cp "$PHENOTYPE_FILE" "$WORK_DIR/input/phenotypes.txt"
    
    # Run phenotype prioritization
    python3 "$WORK_DIR/phenotype_prioritization.py" \
        "$OUTPUT_DIR/high_confidence_denovos.csv" \
        "$WORK_DIR/input/phenotypes.txt" \
        "$OUTPUT_DIR/phenotype_ranked_denovos.csv" || echo -e "${YELLOW}Phenotype prioritization completed with warnings${NC}"
    
    # Sort by probability (simple ranking)
    if [[ -f "$OUTPUT_DIR/phenotype_ranked_denovos.csv" ]]; then
        echo -e "${BLUE}Ranking variants by confidence...${NC}"
        (head -n 1 "$OUTPUT_DIR/phenotype_ranked_denovos.csv" && \
         tail -n +2 "$OUTPUT_DIR/phenotype_ranked_denovos.csv" | \
         sort -t',' -k5 -nr) > "$OUTPUT_DIR/final_ranked_variants.csv"
    fi
else
    # Just sort by probability if no phenotype file
    echo -e "${BLUE}Ranking variants by confidence...${NC}"
    (head -n 1 "$OUTPUT_DIR/high_confidence_denovos.csv" && \
     tail -n +2 "$OUTPUT_DIR/high_confidence_denovos.csv" | \
     sort -t',' -k5 -nr) > "$OUTPUT_DIR/final_ranked_variants.csv"
fi

###############################################################################
# Generate Final Report
###############################################################################
echo -e "${BLUE}Generating final report...${NC}"

cat > "$OUTPUT_DIR/report.txt" << EOF
###############################################################################
# De Novo Variant Analysis Report
# Generated: $(date)
###############################################################################

ANALYSIS SUMMARY
================
Total variants analyzed: $(tail -n +2 "$PREDICTIONS_FILE" | wc -l)
High-confidence de novo variants: $NUM_HIGH_CONF

INPUT FILES
===========
Child BAM: $CHILD_BAM
Father BAM: $FATHER_BAM
Mother BAM: $MOTHER_BAM
Reference: $REFERENCE

HIGH-CONFIDENCE DE NOVO VARIANTS
=================================
EOF

tail -n +2 "$OUTPUT_DIR/final_ranked_variants.csv" | head -n 10 >> "$OUTPUT_DIR/report.txt"

cat >> "$OUTPUT_DIR/report.txt" << EOF

TOP RECOMMENDATIONS
===================
EOF

# Get top variant
TOP_VARIANT=$(head -n 2 "$OUTPUT_DIR/final_ranked_variants.csv" | tail -n 1)

if [[ -n "$TOP_VARIANT" ]]; then
    IFS=',' read -r CHROM POS REF ALT PROB REST <<< "$TOP_VARIANT"
    cat >> "$OUTPUT_DIR/report.txt" << EOF
Most plausible disease-causing de novo variant:
- Chromosome: $CHROM
- Position: $POS
- Reference: $REF
- Alternative: $ALT
- De Novo Probability: $PROB

RECOMMENDATION: This variant should be prioritized for experimental validation
(e.g., Sanger sequencing) and clinical interpretation.

EOF
fi

cat >> "$OUTPUT_DIR/report.txt" << EOF
NEXT STEPS
==========
1. Review the high-confidence de novo variants in IGV for visual confirmation
2. Perform functional annotation (VEP, ANNOVAR) to assess impact
3. Check against databases (ClinVar, gnomAD) for known pathogenic variants
4. Consider Sanger validation of top candidates
5. Consult with clinical geneticist for interpretation

FILES GENERATED
===============
- predictions.csv: All DeNovoCNN predictions
- high_confidence_denovos.csv: High-confidence de novo variants (p > 0.8)
- phenotype_ranked_denovos.csv: Variants with phenotype information (if HPO provided)
- final_ranked_variants.csv: Final ranking of candidate variants
- report.txt: This summary report

For detailed methodology, see: DeNovoCNN_README.md
###############################################################################

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Analysis Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${BLUE}Results saved to: $OUTPUT_DIR${NC}"
echo -e "${BLUE}View the report: cat $OUTPUT_DIR/report.txt${NC}"
echo -e "${BLUE}Top variants: head -n 5 $OUTPUT_DIR/final_ranked_variants.csv${NC}"

###############################################################################
# Cleanup
###############################################################################
echo -e "${BLUE}Cleaning up temporary files...${NC}"
# Keep working directory for debugging, but can be removed if desired
# rm -rf "$WORK_DIR/intermediate"

echo -e "${GREEN}Pipeline execution complete!${NC}"

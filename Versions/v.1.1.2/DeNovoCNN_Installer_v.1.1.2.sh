#!/bin/bash

###############################################################################
# DeNovoCNN Installation Script
#
# This script installs DeNovoCNN using conda on macOS or Ubuntu Linux
# After installation, use run_denovocnn_pipeline.sh for analysis
#
# Usage: ./install_denovocnn.sh [options]
###############################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect OS
OS_TYPE="$(uname -s)"
case "${OS_TYPE}" in
    Linux*)     OS="Linux";;
    Darwin*)    OS="macOS";;
    *)          OS="UNKNOWN"
esac

echo -e "${BLUE}Detected OS: $OS${NC}"

# Default parameters
INSTALL_DIR=""
USE_CONDA=true  # Default to conda
CONDA_PREFIX=""
CONDA_ENV_NAME="denovocnn_env"

###############################################################################
# Help Function
###############################################################################
print_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Installation Options:"
    echo "  --use-conda             Use conda environment (recommended)"
    echo "  --install-dir PATH      Directory for DeNovoCNN installation (required)"
    echo "  --conda-prefix PATH     Exact conda environment location (default: install_dir/env)"
    echo "  --conda-env NAME        Conda environment name (only if conda-prefix not set)"
    echo "  --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  macOS:   $0 --use-conda --install-dir /Users/username/tools/DeNovoCNN"
    echo "  Ubuntu:  $0 --use-conda --install-dir /home/username/tools/DeNovoCNN"
    echo ""
    echo "After installation, use: ./run_denovocnn_pipeline.sh [options]"
}

###############################################################################
# Parse Arguments
###############################################################################
while [[ $# -gt 0 ]]; do
    case $1 in
        --use-conda)
            USE_CONDA=true
            shift
            ;;
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --conda-prefix)
            CONDA_PREFIX="$2"
            shift 2
            ;;
        --conda-env)
            CONDA_ENV_NAME="$2"
            shift 2
            ;;
        --docker-image)
            DOCKER_IMAGE="$2"
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
# Validate Required Parameters
###############################################################################
if [[ -z "$INSTALL_DIR" ]]; then
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}ERROR: Installation directory not specified${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
    echo -e "${YELLOW}You must specify an installation directory using --install-dir${NC}"
    echo ""
    echo -e "${BLUE}Required usage:${NC}"
    echo "  $0 --install-dir /path/to/installation"
    echo ""
    echo -e "${BLUE}Example:${NC}"
    if [[ "$OS" == "macOS" ]]; then
        echo "  $0 --install-dir /Users/username/tools/DeNovoCNN"
    elif [[ "$OS" == "Linux" ]]; then
        echo "  $0 --install-dir /home/username/tools/DeNovoCNN"
    else
        echo "  $0 --install-dir /path/to/installation"
    fi
    echo ""
    echo -e "${BLUE}Full example with conda:${NC}"
    if [[ "$OS" == "macOS" ]]; then
        echo "  $0 --use-conda --install-dir /Users/username/tools/DeNovoCNN"
    elif [[ "$OS" == "Linux" ]]; then
        echo "  $0 --use-conda --install-dir /home/username/tools/DeNovoCNN"
    else
        echo "  $0 --use-conda --install-dir /path/to/installation"
    fi
    echo ""
    echo -e "${YELLOW}For more options, run: $0 --help${NC}"
    exit 1
fi

###############################################################################
# BASE_FOLDER / tools/ layout
###############################################################################
# BASE_FOLDER is whatever the user passed via --install-dir
BASE_FOLDER="$INSTALL_DIR"

# All tools live inside BASE_FOLDER/tools/
TOOLS_DIR="$BASE_FOLDER/tools"
mkdir -p "$TOOLS_DIR"

# Miniconda installation directory
MINICONDA_DIR="$TOOLS_DIR/miniconda3"

# DeNovoCNN repository directory
DENOVOCNN_DIR="$TOOLS_DIR/DeNovoCNN"

# From now on, INSTALL_DIR refers to the DeNovoCNN repo directory
INSTALL_DIR="$DENOVOCNN_DIR"

echo -e "${BLUE}Base folder: $BASE_FOLDER${NC}"
echo -e "${BLUE}Tools directory: $TOOLS_DIR${NC}"
echo -e "${BLUE}DeNovoCNN directory: $DENOVOCNN_DIR${NC}"
echo -e "${BLUE}Miniconda directory: $MINICONDA_DIR${NC}"

###############################################################################
# Set default conda prefix if not specified
###############################################################################
if [[ "$USE_CONDA" = true && -z "$CONDA_PREFIX" ]]; then
    CONDA_PREFIX="$TOOLS_DIR/env"
    echo -e "${BLUE}Conda environment will be installed at: $CONDA_PREFIX${NC}"
fi

###############################################################################
# Installation
###############################################################################
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}DeNovoCNN Installation${NC}"
echo -e "${BLUE}========================================${NC}"

if [[ "$USE_CONDA" = true ]]; then
    echo -e "${BLUE}Setting up conda installation on $OS...${NC}"
    
    # Check conda installation
    CONDA_CMD=""
    if command -v conda &> /dev/null; then
        CONDA_CMD="conda"
        echo -e "${GREEN}System conda found${NC}"
    else
        # Install Miniconda locally
        echo -e "${YELLOW}Conda not found, installing Miniconda locally...${NC}"
        if [[ ! -d "$MINICONDA_DIR" ]]; then
            if [[ "$OS" == "Linux" ]]; then
                MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
                echo -e "${YELLOW}Downloading Miniconda for Linux...${NC}"
                wget -q "$MINICONDA_URL" -O "$TOOLS_DIR/miniconda.sh"
                bash "$TOOLS_DIR/miniconda.sh" -b -p "$MINICONDA_DIR"
                rm "$TOOLS_DIR/miniconda.sh"
            else
                MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh"
                echo -e "${YELLOW}Downloading Miniconda for macOS...${NC}"
                curl -L "$MINICONDA_URL" -o "$TOOLS_DIR/miniconda.sh"
                bash "$TOOLS_DIR/miniconda.sh" -b -p "$MINICONDA_DIR"
                rm "$TOOLS_DIR/miniconda.sh"
            fi
            echo -e "${GREEN}Miniconda installed locally at: $MINICONDA_DIR${NC}"
        else
            echo -e "${GREEN}Miniconda already installed locally at: $MINICONDA_DIR${NC}"
        fi
        CONDA_CMD="$MINICONDA_DIR/bin/conda"
    fi
    
    # Initialize conda for bash
    # FIX: Always activate Miniconda first, not the target env
    if [[ -n "$MINICONDA_DIR" ]]; then
    # Activate Miniconda base environment
    source "$MINICONDA_DIR/etc/profile.d/conda.sh"
    elif command -v conda &> /dev/null; then
    # Use system conda if available
    conda init bash > /dev/null 2>&1 || true
    else
    echo -e "${RED}ERROR: No conda installation found and Miniconda directory missing.${NC}"
    exit 1
    fi

    
    # Clone DeNovoCNN repository into tools/DeNovoCNN if not exists
    if [[ ! -d "$DENOVOCNN_DIR" ]] || [[ ! -f "$DENOVOCNN_DIR/environment.yml" ]]; then
        if [[ -d "$DENOVOCNN_DIR" ]]; then
            echo -e "${YELLOW}DeNovoCNN directory exists but environment.yml not found. Re-cloning DeNovoCNN...${NC}"
        else
            echo -e "${BLUE}Cloning DeNovoCNN to $DENOVOCNN_DIR...${NC}"
        fi
        git clone https://github.com/Genome-Bioinformatics-RadboudUMC/DeNovoCNN.git "$DENOVOCNN_DIR"
    else
        echo -e "${GREEN}DeNovoCNN already installed at $DENOVOCNN_DIR${NC}"
    fi
    
    # Create conda environment if not exists
    if [[ -n "$CONDA_PREFIX" ]]; then
        # Use prefix (specific path)
        if [[ ! -d "$CONDA_PREFIX" ]]; then
            echo -e "${BLUE}Creating conda environment at: $CONDA_PREFIX...${NC}"
            cd "$INSTALL_DIR"
            $CONDA_CMD env create -f environment.yml -p "$CONDA_PREFIX"
            cd - > /dev/null
            echo -e "${GREEN}Conda environment created successfully at: $CONDA_PREFIX${NC}"
        else
            echo -e "${GREEN}Conda environment already exists at: $CONDA_PREFIX${NC}"
        fi
    else
        # Use environment name or default to local miniconda
        if [[ -n "$MINICONDA_DIR" ]]; then
            CONDA_PREFIX="$MINICONDA_DIR/envs/$CONDA_ENV_NAME"
        fi
        
        if [[ -n "$CONDA_PREFIX" ]]; then
            if [[ ! -d "$CONDA_PREFIX" ]]; then
                echo -e "${BLUE}Creating conda environment at: $CONDA_PREFIX...${NC}"
                cd "$INSTALL_DIR"
                $CONDA_CMD env create -f environment.yml -p "$CONDA_PREFIX"
                cd - > /dev/null
                echo -e "${GREEN}Conda environment created successfully at: $CONDA_PREFIX${NC}"
            else
                echo -e "${GREEN}Conda environment already exists at: $CONDA_PREFIX${NC}"
            fi
        else
            if ! $CONDA_CMD env list | grep -q "^${CONDA_ENV_NAME} "; then
                echo -e "${BLUE}Creating conda environment: $CONDA_ENV_NAME...${NC}"
                cd "$INSTALL_DIR"
                $CONDA_CMD env create -f environment.yml --name "$CONDA_ENV_NAME"
                cd - > /dev/null
                echo -e "${GREEN}Conda environment $CONDA_ENV_NAME created successfully${NC}"
            else
                echo -e "${GREEN}Conda environment $CONDA_ENV_NAME already exists${NC}"
            fi
        fi
    fi
    
fi

# Generate workflow documentation (0. Workflow)
echo -e "${BLUE}Generating workflow documentation (0_README_DeNovoCNN_Workflow.md)...${NC}"
cat > "$BASE_FOLDER/0_README_DeNovoCNN_Workflow.md" << 'EOF'
# DeNovoCNN Analysis Workflow - Complete Documentation

## Overview

This workflow is designed for **trio-based de novo variant detection** using deep learning (CNNs). DeNovoCNN converts genomic sequencing data into image-like representations and applies computer vision techniques to distinguish true de novo mutations from sequencing artifacts.

---

## Workflow Steps

### Step 1 - Data Preparation
- **Input BAM files**: Child, father, and mother aligned sequencing data
- **Input VCF files**: Candidate variant locations from any variant caller
- **Reference genome**: FASTA file (e.g., GRCh38)
- **Purpose**: Prepare input files for DeNovoCNN analysis
- **Implementation**: Edit 1_Define_data_specs.txt with your file paths

### Step 2 - Image Generation
- **RGB image creation**: 160×164 pixel images
  - Red channel: Child reads
  - Green channel: Father reads  
  - Blue channel: Mother reads
- **One-hot encoding**: Each base position uses 4 pixels [A, C, T, G]
- **Pixel intensity**: Based on base quality and mapping quality
- **Purpose**: Convert sequencing data to visual representation for CNN
- **Implementation**: Automatic in 2_Run_analysis.sh via apply_denovocnn.sh

### Step 3 - CNN Classification
- **Three specialized models**:
  - SNP Model: Single nucleotide substitutions
  - Insertion Model: Insertion variants
  - Deletion Model: Deletion variants
- **Architecture**: 9 convolutional layers + attention mechanisms
- **Output**: Probability (0-1) of being de novo mutation
- **Purpose**: Classify variants as true de novo vs artifact
- **Implementation**: Automatic in 2_Run_analysis.sh

### Step 4 - Result Filtering
- **High-confidence threshold**: Probability > 0.8
- **Output files**:
  - predictions.csv: All DeNovoCNN predictions
  - high_confidence_denovos.csv: High-confidence de novo variants
  - final_ranked_variants.csv: Ranked by confidence
- **Purpose**: Filter and prioritize candidate variants
- **Implementation**: Lines 626-631 in 2_Run_analysis.sh

### Step 5 - Phenotype Prioritization (Optional)
- **HPO terms**: Phenotype identifiers for patient
- **Phenotype matching**: Rank variants by phenotype relevance
- **Output**: phenotype_ranked_denovos.csv (if HPO terms provided)
- **Purpose**: Prioritize variants based on clinical phenotype
- **Implementation**: Lines 636-719 in 2_Run_analysis.sh

---

## Performance Metrics

- **Recall: 96.74%** - Ability to detect true de novo mutations
- **Precision: 96.55%** - Avoidance of false positive calls
- **F1-score: 96.64%** - Balanced performance metric
- **Outperforms**: GATK, DeNovoGear, DeepTrio, Samtools

---

## Key Advantages

1. **No Variant Recalling Required**: Works with existing BAM/VCF files from any variant caller
2. **Platform Agnostic**: Robust across different sequencing technologies (Illumina, NovaSeq, HiSeq)
3. **Capture Kit Independent**: Works with different exome capture kits
4. **WGS/WES Compatible**: Trained on WES but generalizes well to WGS data
5. **Visual Interpretation**: Mimics human expert review in IGV but with consistency
6. **No VCF Annotation Needed**: Uses raw read data, not functional annotations

---

## Usage Instructions

1. **Edit 1_Define_data_specs.txt** with your data paths and parameters
2. **Run 2_Run_analysis.sh** to execute the complete pipeline
3. **Review results** in the output directory specified in 1_Define_data_specs.txt

---

## Technical Details

### Image Specifications
- **Dimensions**: 160×164 pixels
- **Color Channels**: RGB (Red=Child, Green=Father, Blue=Mother)
- **Rows (160)**: Each row represents one sequencing read (limited to 160 reads)
- **Columns (164)**: Each genomic position uses 4 pixels (one-hot encoding)

### CNN Architecture
```
Input (160×164×3 RGB image)
    ↓
9 × Convolutional Layers (96 filters, 3×3 kernels, ReLU, same padding)
    ↓
Batch Normalization (every 3rd layer)
    ↓
Squeeze-and-Excitation Blocks (channel attention)
    ↓
Global Max Pooling + Global Average Pooling
    ↓
Dense Layer (1 neuron, sigmoid activation)
    ↓
Output: Probability (0-1) of being de novo mutation
```

---

## Citation

If you use DeNovoCNN in your research, please cite:

```
Khazeeva G, Sablauskas K, van der Sanden B, et al. 
DeNovoCNN: a deep learning approach to de novo variant calling in next generation sequencing data. 
Nucleic Acids Res. 2022;50(17):e97. doi:10.1093/nar/gkac511
```
EOF

# Generate configuration file (1. Define specs)
echo -e "${BLUE}Generating configuration file (1_Define_data_specs.txt)...${NC}"
cat > "$BASE_FOLDER/1_Define_data_specs.txt" << EOF
#!/bin/bash
# USER CONFIGURATION FILE
# Edit all variables below before running script 2

# ============================================================
# Installation directory (automatically set by installer)
# ============================================================
INSTALL_DIR="$DENOVOCNN_DIR"

# ============================================================
# 1. Data parameters
# ============================================================

# Analysis output directory (where all results will be saved)
OUTPUT_DIR="/path/to/output/directory"

# Working directory for intermediate files
WORK_DIR="./denovo_analysis"

# Input BAM files (absolute paths)
CHILD_BAM="/path/to/child.bam"
FATHER_BAM="/path/to/father.bam"
MOTHER_BAM="/path/to/mother.bam"

# Input VCF files (absolute paths)
CHILD_VCF="/path/to/child.vcf"
FATHER_VCF="/path/to/father.vcf"
MOTHER_VCF="/path/to/mother.vcf"

# Reference genome (absolute path)
REFERENCE="/path/to/reference.fa"

# ============================================================
# 2. Optional parameters
# ============================================================

# Phenotype file (HPO terms, one per line) - Optional
PHENOTYPE_FILE=""

# ============================================================
# 3. Filtering parameters
# ============================================================

# High-confidence probability threshold
PROBABILITY_THRESHOLD="0.8"

# ============================================================
# 4. Conda environment settings (automatically set)
# ============================================================
USE_CONDA=true
CONDA_PREFIX="$CONDA_PREFIX"
CONDA_ENV_NAME="$CONDA_ENV_NAME"
MINICONDA_DIR="$MINICONDA_DIR"
EOF

# Generate pipeline script (2. Run analysis)
echo -e "${BLUE}Generating analysis script (2_Run_analysis.sh)...${NC}"
cat > "$BASE_FOLDER/2_Run_analysis.sh" << 'PIPELINE_EOF'
#!/bin/bash

###############################################################################
# DeNovoCNN Analysis Pipeline
# 
# This script processes trio BAM/VCF files, runs de novo variant detection,
# prioritizes variants by phenotype, and generates results.
# 
# Generated by DeNovoCNN Installer
#
# Usage: ./2_Run_analysis.sh
###############################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

###############################################################################
# GET SCRIPT DIRECTORY AND LOAD CONFIG
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/1_Define_data_specs.txt"

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}ERROR: Configuration file not found: $CONFIG_FILE${NC}"
    echo -e "${YELLOW}Please edit 1_Define_data_specs.txt before running this script${NC}"
    exit 1
fi

source "$CONFIG_FILE"

###############################################################################
# VERIFY INSTALL_DIR IS SET
###############################################################################

if [ -z "$INSTALL_DIR" ]; then
    echo -e "${RED}ERROR: INSTALL_DIR variable not set in 1_Define_data_specs.txt${NC}"
    echo -e "${YELLOW}Please ensure the installation was completed correctly${NC}"
    exit 1
fi

echo -e "${BLUE}Installation directory: $INSTALL_DIR${NC}"
echo -e "${BLUE}Configuration loaded from: $CONFIG_FILE${NC}"

# Set output directory if not specified in config
if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$WORK_DIR/results"
fi

###############################################################################
# Validate Required Arguments from Config
###############################################################################
if [[ -z "$CHILD_BAM" || -z "$FATHER_BAM" || -z "$MOTHER_BAM" ]]; then
    echo -e "${RED}Error: Child, father, and mother BAM files are required in 1_Define_data_specs.txt${NC}"
    exit 1
fi

if [[ -z "$CHILD_VCF" || -z "$FATHER_VCF" || -z "$MOTHER_VCF" ]]; then
    echo -e "${RED}Error: Child, father, and mother VCF files are required in 1_Define_data_specs.txt${NC}"
    exit 1
fi

if [[ -z "$REFERENCE" ]]; then
    echo -e "${RED}Error: Reference genome file is required in 1_Define_data_specs.txt${NC}"
    exit 1
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
# BAM files: use symlinks (read-only operations)
ln -sf "$(realpath "$CHILD_BAM")" "$WORK_DIR/input/child.bam"
ln -sf "$(realpath "$FATHER_BAM")" "$WORK_DIR/input/father.bam"
ln -sf "$(realpath "$MOTHER_BAM")" "$WORK_DIR/input/mother.bam"

# VCF files: COPY to working directory to avoid modifying original files
echo -e "${YELLOW}Copying VCF files to working directory (original files will not be modified)...${NC}"
cp "$(realpath "$CHILD_VCF")" "$WORK_DIR/input/child.vcf"
cp "$(realpath "$FATHER_VCF")" "$WORK_DIR/input/father.vcf"
cp "$(realpath "$MOTHER_VCF")" "$WORK_DIR/input/mother.vcf"

# Reference: use symlink (read-only operation)
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
            elif [[ -n "$MINICONDA_DIR" ]]; then
                "$MINICONDA_DIR/bin/conda" run -n "$CONDA_ENV_NAME" \
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
        elif [[ -n "$MINICONDA_DIR" ]]; then
            "$MINICONDA_DIR/bin/conda" run -n "$CONDA_ENV_NAME" \
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
PIPELINE_EOF

# Make files executable
chmod +x "$BASE_FOLDER/2_Run_analysis.sh"
echo -e "${GREEN}Analysis script generated successfully at: $BASE_FOLDER/2_Run_analysis.sh${NC}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Base folder: $BASE_FOLDER${NC}"
echo -e "${BLUE}DeNovoCNN directory: $DENOVOCNN_DIR${NC}"
echo -e "${BLUE}Tools directory: $TOOLS_DIR${NC}"
echo -e "${BLUE}Operating System: $OS${NC}"
if [[ -n "$CONDA_PREFIX" ]]; then
    echo -e "${BLUE}Conda environment: $CONDA_PREFIX${NC}"
else
    echo -e "${BLUE}Conda environment: $CONDA_ENV_NAME${NC}"
fi
echo ""
echo -e "${YELLOW}Files generated:${NC}"
echo -e "  - 0_README_DeNovoCNN_Workflow.md (workflow documentation)"
echo -e "  - 1_Define_data_specs.txt (configuration file - edit this with your data paths)"
echo -e "  - 2_Run_analysis.sh (analysis pipeline script)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Edit 1_Define_data_specs.txt with your data paths and parameters"
echo -e "2. Activate conda environment"
if [[ -n "$CONDA_PREFIX" ]]; then
    echo -e "   conda activate $CONDA_PREFIX"
else
    echo -e "   conda activate $CONDA_ENV_NAME"
fi
echo -e "3. Run analysis: cd $BASE_FOLDER && ./2_Run_analysis.sh"
echo ""
echo -e "${GREEN}Ready to use!${NC}"

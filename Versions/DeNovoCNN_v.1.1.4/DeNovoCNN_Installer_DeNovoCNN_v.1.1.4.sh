#!/bin/bash

###############################################################################
# DeNovoCNN Installer (Ubuntu Linux + conda only)
#
# Installs DeNovoCNN using conda or Miniconda (auto fallback).
# Works on Ubuntu Linux only.
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# OS Detection - Ubuntu Linux only
OS="Linux"
echo -e "${BLUE}DeNovoCNN Installer for Ubuntu Linux${NC}"

# Defaults
INSTALL_DIR=""
CONDA_PREFIX=""
CONDA_ENV_NAME="denovocnn_env"

###############################################################################
# Help
###############################################################################
print_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --install-dir PATH      Installation directory (required)"
    echo "  --conda-prefix PATH     Full path to conda environment"
    echo "  --conda-env NAME        Environment name (if prefix not used)"
    echo "  --help                  Show help"
}

###############################################################################
# Parse arguments
###############################################################################
while [[ $# -gt 0 ]]; do
    case "$1" in
        --install-dir) INSTALL_DIR="$2"; shift 2 ;;
        --conda-prefix) CONDA_PREFIX="$2"; shift 2 ;;
        --conda-env) CONDA_ENV_NAME="$2"; shift 2 ;;
        --help) print_help; exit 0 ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; print_help; exit 1 ;;
    esac
done

###############################################################################
# Validate install dir
###############################################################################
if [[ -z "$INSTALL_DIR" ]]; then
    echo -e "${RED}ERROR: --install-dir is required${NC}"
    exit 1
fi

###############################################################################
# Directory layout
###############################################################################
BASE_FOLDER="$INSTALL_DIR"
TOOLS_DIR="$BASE_FOLDER/tools"
mkdir -p "$TOOLS_DIR"

MINICONDA_DIR="$TOOLS_DIR/miniconda3"
DENOVOCNN_DIR="$TOOLS_DIR/DeNovoCNN"
IGV_INSTALLATION_DIR="$TOOLS_DIR/IGV_Snapshot"
IGV_REPO_URL="https://github.com/stevekm/IGV-snapshot-automator.git"
IGV_GENOME="hg38"
IGV_MEMORY="8g"
VIEWPORT_FRACTION="15"
SNAPSHOT_WIDTH="4000"
SNAPSHOT_HEIGHT="1200"

INSTALL_DIR="$DENOVOCNN_DIR"

echo -e "${BLUE}Base folder: $BASE_FOLDER${NC}"
echo -e "${BLUE}Tools directory: $TOOLS_DIR${NC}"
echo -e "${BLUE}DeNovoCNN directory: $DENOVOCNN_DIR${NC}"
echo -e "${BLUE}Miniconda directory: $MINICONDA_DIR${NC}"
echo -e "${BLUE}IGV Snapshot directory: $IGV_INSTALLATION_DIR${NC}"

###############################################################################
# Set default conda prefix
###############################################################################
if [[ -z "$CONDA_PREFIX" ]]; then
    CONDA_PREFIX="$TOOLS_DIR/env"
    echo -e "${BLUE}Conda environment will be installed at: $CONDA_PREFIX${NC}"
fi

###############################################################################
# Installation
###############################################################################
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}DeNovoCNN Installation${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "${BLUE}Checking conda installation...${NC}"

    # Detect system conda
    if command -v conda &> /dev/null; then
        echo -e "${GREEN}System conda found${NC}"
        CONDA_CMD="conda"
    else
        echo -e "${YELLOW}System conda not found — installing Miniconda locally${NC}"

        if [[ ! -d "$MINICONDA_DIR" ]]; then
            URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
            curl -L "$URL" -o "$TOOLS_DIR/miniconda.sh"
            bash "$TOOLS_DIR/miniconda.sh" -b -p "$MINICONDA_DIR"
            rm "$TOOLS_DIR/miniconda.sh"
            echo -e "${GREEN}Miniconda installed at $MINICONDA_DIR${NC}"
        else
            echo -e "${GREEN}Miniconda already installed${NC}"
        fi

        CONDA_CMD="$MINICONDA_DIR/bin/conda"
    fi

    ###########################################################################
    # Correct conda initialization logic
    ###########################################################################
    if [[ -d "$MINICONDA_DIR" ]]; then
        echo -e "${GREEN}Activating Miniconda${NC}"
        source "$MINICONDA_DIR/etc/profile.d/conda.sh"
        ACTUAL_CONDA_DIR="$MINICONDA_DIR"
        echo -e "${GREEN}Using local Miniconda at: $ACTUAL_CONDA_DIR${NC}"
    else
        echo -e "${GREEN}Using system conda${NC}"
        conda init bash > /dev/null 2>&1 || true
        # Get system conda base path
        ACTUAL_CONDA_DIR=$(conda info --base 2>/dev/null || echo "")
        echo -e "${GREEN}System conda detected at: $ACTUAL_CONDA_DIR${NC}"
    fi

    ###########################################################################
    # FIX: Disable strict priority + enable conda-forge
    ###########################################################################
    echo -e "${BLUE}Applying conda channel priority fix...${NC}"
    conda config --set channel_priority flexible
    conda config --add channels conda-forge 2>/dev/null || true
    conda config --add channels defaults 2>/dev/null || true
    echo -e "${GREEN}Conda priority fixed (flexible) and conda-forge enabled${NC}"

    ###########################################################################
    # Clone DeNovoCNN
    ###########################################################################
    if [[ ! -d "$DENOVOCNN_DIR" ]] || [[ ! -f "$DENOVOCNN_DIR/environment.yml" ]]; then
        echo -e "${BLUE}Cloning DeNovoCNN repository...${NC}"
        git clone https://github.com/Genome-Bioinformatics-RadboudUMC/DeNovoCNN.git "$DENOVOCNN_DIR"
    else
        echo -e "${GREEN}DeNovoCNN already present${NC}"
    fi

    ###########################################################################
    # Create conda environment
    ###########################################################################
    echo -e "${BLUE}Creating conda environment...${NC}"

    if [[ ! -d "$CONDA_PREFIX" ]]; then
        cd "$DENOVOCNN_DIR"
        $CONDA_CMD env create -f environment.yml -p "$CONDA_PREFIX"
        cd - > /dev/null
        echo -e "${GREEN}Environment created at $CONDA_PREFIX${NC}"
    else
        echo -e "${GREEN}Environment already exists at $CONDA_PREFIX${NC}"
    fi

###############################################################################
# System Dependencies for IGV (Ubuntu Linux)
###############################################################################
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Installing IGV Dependencies${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "${BLUE}Installing IGV dependencies for Ubuntu Linux...${NC}"
sudo apt-get update
sudo apt-get install -y python3 python3-pip wget unzip xvfb x11-utils default-jre openjdk-8-jre git

###############################################################################
# IGV Snapshot Automator Installation
###############################################################################
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Installing IGV Snapshot Automator${NC}"
echo -e "${BLUE}========================================${NC}"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

log "[1/6] IGV dependencies already installed in auth phase..."

# Detect Java 8 path (Linux/Ubuntu)
JAVA8_PATH=$(update-alternatives --list java 2>/dev/null | grep "java-8" | head -n 1)
if [ -z "$JAVA8_PATH" ]; then
    log "ERROR: Java 8 not found"
    exit 1
fi
log "Java 8 detected at: $JAVA8_PATH"

log "[2/6] Cloning IGV repository..."
rm -rf "$IGV_INSTALLATION_DIR"
cd "$TOOLS_DIR"
git clone "$IGV_REPO_URL" "IGV_Snapshot"

log "[3/6] Installing IGV..."
cd "$IGV_INSTALLATION_DIR"
make install

PATCH_FILE="$IGV_INSTALLATION_DIR/make_IGV_snapshots.py"
cp "$PATCH_FILE" "$PATCH_FILE.bak"

log "[4/6] Applying patches..."

# Disable X-server detection
sed -i 's/x_serv_port = get_open_X_server()/# x_serv_port = get_open_X_server()/g' "$PATCH_FILE"
sed -i 's/print(.*x_serv_port.*)//g' "$PATCH_FILE"

# Replace IGV command with Java 8 + xvfb-run
sed -i "s|java -Xmx|xvfb-run -a $JAVA8_PATH -Xmx|g" "$PATCH_FILE"

# Insert width/height AFTER the -s argument block
sed -i '/help="Group reads by forward\/reverse strand."/a \
    parser.add_argument("-w", "--width", type=int, default=2000, help="Snapshot width in pixels")\n    parser.add_argument("-H", "--height", type=int, default=800, help="Snapshot height in pixels")' "$PATCH_FILE"

# Fix batchscript writer
sed -i 's/batchscript.write("snapshotHeight/batchscript.write("snapshotWidth {}\\n".format(args.width))\nbatchscript.write("snapshotHeight/' "$PATCH_FILE"

# Add annotation track argument
sed -i '/parser.add_argument("-H", "--height"/a\    parser.add_argument("-a", "--annotation", help="Annotation BED file for variant highlighting")' "$PATCH_FILE"

# Add annotation track loading with red color
sed -i '/batchscript.write("load /i\            if args.annotation:\n                batchscript.write("load {}\\n".format(args.annotation))\n                batchscript.write("color 255,0,0\\n")' "$PATCH_FILE

log "[5/6] Setting permissions..."
chmod +x "$PATCH_FILE"

log "[6/6] IGV Snapshot Automator installation complete."
log "Patched Python script:"
log "  - Adds -w (width) parameter"
log "  - Adds -H (height) parameter"
log "  - Adds -a (annotation) parameter for red variant highlighting"
log "  - Uses Java 8"
log "  - Uses xvfb-run for headless operation"
log "  - Disables X-server detection"
log "  - Adds red annotation track for variant highlighting"
log ""
log "Run IGV snapshots with:"
log "  cd $IGV_INSTALLATION_DIR"
log "  python3 make_IGV_snapshots.py -w 4000 -H 1200 ..."

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}IGV installation complete${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "${GREEN}Installation complete!${NC}"

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

## IGV Snapshot Integration

This installer includes **IGV Snapshot Automator** for automated generation of IGV screenshots of genomic regions containing candidate de novo variants.

### IGV Snapshot Features
- **Automated screenshot generation**: Generate IGV snapshots for multiple genomic regions in batch
- **Customizable dimensions**: Specify snapshot width (-w) and height (-H) parameters
- **Headless operation**: Uses xvfb-run on Linux for server environments without display
- **Java 8 optimized**: Configured to use Java 8 for compatibility
- **Enhanced parameters**: Added width and height arguments for flexible screenshot sizing

### Usage

```bash
cd $IGV_INSTALLATION_DIR
python3 make_IGV_snapshots.py -w 4000 -H 1200 [options]
```

### Common Parameters
- `-r`: Regions file (BED format)
- `-o`: Output directory for snapshots
- `-g`: Genome assembly (e.g., hg38)
- `-mem`: Memory allocation (e.g., 8g)
- `-w, --width`: Snapshot width in pixels (default: 2000)
- `-H, --height`: Snapshot height in pixels (default: 800)
- BAM files: Pass BAM files as arguments at the end

### Example: Generate IGV snapshots for high-confidence de novo variants

After running DeNovoCNN analysis, you can generate IGV snapshots for the high-confidence variants:

```bash
cd $IGV_INSTALLATION_DIR
python3 make_IGV_snapshots.py \
  -r regions.bed \
  -o /path/to/output/snapshots \
  -g hg38 \
  -mem 8g \
  -w 4000 -H 1200 \
  /path/to/child.bam \
  /path/to/father.bam \
  /path/to/mother.bam
```

The regions.bed file should be in BED format with columns: chrom, start, end, name

### Platform Notes
- **Ubuntu Linux**: Uses xvfb-run for headless operation (no display required)
- **Java 8**: Required for IGV compatibility

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
# 2. Filtering parameters
# ============================================================

# High-confidence probability threshold
PROBABILITY_THRESHOLD="0.8"

# ============================================================
# 3. Conda environment settings (automatically set)
# ============================================================
CONDA_PREFIX="$CONDA_PREFIX"
CONDA_ENV_NAME="$CONDA_ENV_NAME"
MINICONDA_DIR="$ACTUAL_CONDA_DIR"

# ============================================================
# 4. IGV Snapshot settings (automatically set)
# ============================================================
IGV_INSTALLATION_DIR="$IGV_INSTALLATION_DIR"
IGV_GENOME="$IGV_GENOME"
IGV_MEMORY="$IGV_MEMORY"
VIEWPORT_FRACTION="$VIEWPORT_FRACTION"
SNAPSHOT_WIDTH="$SNAPSHOT_WIDTH"
SNAPSHOT_HEIGHT="$SNAPSHOT_HEIGHT"
EOF

# Generate pipeline script (2. Run analysis)
echo -e "${BLUE}Generating analysis script (2_Run_analysis.sh)...${NC}"
cat > "$BASE_FOLDER/2_Run_analysis.sh" << 'PIPELINE_EOF'
#!/bin/bash

###############################################################################
# DeNovoCNN Analysis Pipeline
# 
# This script processes trio BAM/VCF files, runs de novo variant detection,
# and generates results.
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
# INITIALIZE CONDA
###############################################################################
if [[ -n "$MINICONDA_DIR" && -d "$MINICONDA_DIR" ]]; then
    echo -e "${BLUE}Initializing conda from Miniconda at $MINICONDA_DIR${NC}"
    source "$MINICONDA_DIR/etc/profile.d/conda.sh"
elif command -v conda &> /dev/null; then
    echo -e "${BLUE}Using system conda${NC}"
    conda init bash > /dev/null 2>&1 || true
else
    echo -e "${RED}Error: Conda not found. Please install conda${NC}"
    exit 1
fi

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

# Set output directory (fixed to results subdirectory)
OUTPUT_DIR="$WORK_DIR/results"

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

# Reference: use symlink (read-only operation) - preserve original extension
REFERENCE_FILENAME=$(basename "$REFERENCE")
ln -sf "$(realpath "$REFERENCE")" "$WORK_DIR/input/$REFERENCE_FILENAME"
REFERENCE_WORKING="$WORK_DIR/input/$REFERENCE_FILENAME"

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
SNP_MODEL="$INSTALL_DIR/models/snp"
INS_MODEL="$INSTALL_DIR/models/ins"
DEL_MODEL="$INSTALL_DIR/models/del"

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
            # Run with conda - use environment path
            if [[ -n "$CONDA_PREFIX" && -d "$CONDA_PREFIX" ]]; then
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
                    -g="$REFERENCE_WORKING" \
                    -v="$part" \
                    -o="$OUTPUT_DIR/predictions_part${part_num}.csv" || true
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
        # Run with conda - use environment path
        if [[ -n "$CONDA_PREFIX" && -d "$CONDA_PREFIX" ]]; then
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
                -g="$REFERENCE_WORKING" \
                -o="$OUTPUT_DIR/predictions.csv"
    else
        echo -e "${RED}Error: Conda environment not found at $CONDA_PREFIX${NC}"
        exit 1
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
# Rank Variants by Confidence
###############################################################################
echo -e "${BLUE}Ranking variants by confidence...${NC}"
(head -n 1 "$OUTPUT_DIR/high_confidence_denovos.csv" && \
 tail -n +2 "$OUTPUT_DIR/high_confidence_denovos.csv" | \
 sort -t',' -k5 -nr) > "$OUTPUT_DIR/final_ranked_variants.csv"

###############################################################################
# Generate IGV Snapshots for High-Confidence De Novo Variants
###############################################################################
echo -e "${BLUE}Generating IGV snapshots for high-confidence de novo variants...${NC}"

# Create snapshots directory
SNAPSHOT_DIR="$OUTPUT_DIR/igv_snapshots"
mkdir -p "$SNAPSHOT_DIR"

# Check if IGV is installed
if [[ -d "$IGV_INSTALLATION_DIR" && -f "$IGV_INSTALLATION_DIR/make_IGV_snapshots.py" ]]; then
    echo -e "${GREEN}IGV Snapshot Automator found at: $IGV_INSTALLATION_DIR${NC}"
    
    # Generate regions file for IGV (BED format)
    REGIONS_FILE="$WORK_DIR/intermediate/high_confidence_regions.bed"
    tail -n +2 "$OUTPUT_DIR/high_confidence_denovos.csv" | while IFS=',' read -r chrom start ref alt prob rest; do
        # Calculate region (position ± 500bp for context)
        region_start=$((start - 500))
        region_end=$((start + 500))
        if [ "$region_start" -lt 1 ]; then region_start=1; fi
        echo -e "${chrom}\t${region_start}\t${region_end}\t${chrom}:${start}"
    done > "$REGIONS_FILE"
    
    # Validate BAM files and reference genome
    VALID_BAM_FILES=()
    for bam in "$WORK_DIR/input/child.bam" "$WORK_DIR/input/father.bam" "$WORK_DIR/input/mother.bam"; do
        if [ -f "$bam" ]; then
            VALID_BAM_FILES+=("$bam")
        fi
    done
    
    REFERENCE_GENOME="$REFERENCE_WORKING"
    
    if [ ${#VALID_BAM_FILES[@]} -eq 0 ]; then
        echo -e "${YELLOW}Warning: No BAM files found for IGV snapshots${NC}"
    else
        # Function to run IGV snapshots (exact working code from Variants_Prioritization)
        run_igv_snapshots() {
            local REGIONS_FILE=$1
            local OUTPUT_DIR=$2
            local RUN_NAME=$3
            
            echo -e "${BLUE}>>> Generating IGV snapshots for ${RUN_NAME}${NC}"
            
            # Expand regions
            TEMP_DIR=$(mktemp -d)
            EXPANDED_REGIONS_FILE="$TEMP_DIR/expanded_regions.bed"
            REGION_INFO_FILE="$TEMP_DIR/region_info.txt"
            ANNOTATION_FILE="$TEMP_DIR/annotation.bed"
            
            echo "Expanding regions for ${RUN_NAME}..."
            while IFS=$'\t' read -r chrom start end name; do
                if [[ "$chrom" =~ ^# ]] || [[ "$chrom" =~ ^track ]]; then
                    continue
                fi
                region_size=$((end - start))
                if [ "$region_size" -lt 1 ]; then region_size=1; fi
                total_window=$((region_size * VIEWPORT_FRACTION))
                padding=$((total_window / 2))
                expanded_start=$((start - padding))
                expanded_end=$((end + padding))
                if [ "$expanded_start" -lt 1 ]; then expanded_start=1; fi
                echo -e "${chrom}\t${expanded_start}\t${expanded_end}\t${name}" >> "$EXPANDED_REGIONS_FILE"
                echo -e "${name}\t${chrom}\t${start}\t${end}" >> "$REGION_INFO_FILE"
                # Create annotation track with original variant position (for red highlighting)
                echo -e "${chrom}\t${start}\t${end}\t${name}" >> "$ANNOTATION_FILE"
            done < "$REGIONS_FILE"
            
            cd "$IGV_INSTALLATION_DIR"
            CMD="python3 make_IGV_snapshots.py"
            CMD="$CMD -r $EXPANDED_REGIONS_FILE"
            CMD="$CMD -o $OUTPUT_DIR"
            CMD="$CMD -g $IGV_GENOME"
            CMD="$CMD --reference $REFERENCE_GENOME"
            CMD="$CMD -mem $IGV_MEMORY"
            CMD="$CMD -w $SNAPSHOT_WIDTH -h $SNAPSHOT_HEIGHT"
            CMD="$CMD -a $ANNOTATION_FILE"
            CMD+=" ${VALID_BAM_FILES[@]}"
            eval $CMD
            
            # Rename output files
            echo "Renaming output files for ${RUN_NAME}..."
            while IFS=$'\t' read -r name chrom start end; do
                for snapshot_file in "$OUTPUT_DIR"/*${name}*.png; do
                    if [ -f "$snapshot_file" ]; then
                        base_name=$(basename "$snapshot_file")
                        new_name="${name}_${chrom}_${start}_${end}.png"
                        mv "$snapshot_file" "$OUTPUT_DIR/$new_name"
                    fi
                done
            done < "$REGION_INFO_FILE"
            
            rm -rf "$TEMP_DIR"
            
            echo -e "${GREEN}>>> IGV snapshots completed for ${RUN_NAME}${NC}"
            echo -e "${GREEN}Snapshots saved to: $OUTPUT_DIR${NC}"
        }
        
        # Run IGV snapshots
        run_igv_snapshots "$REGIONS_FILE" "$SNAPSHOT_DIR" "DeNovoCNN"
        
        # Create snapshot index file
        echo "region,snapshot_file" > "$SNAPSHOT_DIR/snapshot_index.csv"
        tail -n +2 "$OUTPUT_DIR/high_confidence_denovos.csv" | while IFS=',' read -r chrom start ref alt prob rest; do
            region_start=$((start - 500))
            region_end=$((start + 500))
            region="${chrom}:${region_start}-${region_end}"
            safe_region=$(echo "$region" | tr ':' '-' | tr ' ' '_')
            echo "${region},denovo_${safe_region}.png"
        done >> "$SNAPSHOT_DIR/snapshot_index.csv"
    fi
    
else
    echo -e "${YELLOW}Warning: IGV Snapshot Automator not found at $IGV_INSTALLATION_DIR${NC}"
    echo -e "${YELLOW}Skipping IGV snapshot generation${NC}"
    echo -e "${YELLOW}To install IGV, please re-run the installer or check the installation directory${NC}"
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
- final_ranked_variants.csv: Final ranking of candidate variants
- igv_snapshots/: IGV screenshots for high-confidence de novo variants
- igv_snapshots/snapshot_index.csv: Index mapping regions to snapshot files
- report.txt: This summary report

IGV SNAPSHOTS
=============
EOF

if [[ -d "$SNAPSHOT_DIR" && -f "$SNAPSHOT_DIR/snapshot_index.csv" ]]; then
    NUM_SNAPSHOTS=$(tail -n +2 "$SNAPSHOT_DIR/snapshot_index.csv" | wc -l)
    echo "IGV snapshots generated: $NUM_SNAPSHOTS" >> "$OUTPUT_DIR/report.txt"
    echo "Snapshot directory: $SNAPSHOT_DIR" >> "$OUTPUT_DIR/report.txt"
    echo "" >> "$OUTPUT_DIR/report.txt"
    echo "Top 5 snapshots:" >> "$OUTPUT_DIR/report.txt"
    head -n 6 "$SNAPSHOT_DIR/snapshot_index.csv" >> "$OUTPUT_DIR/report.txt"
else
    echo "IGV snapshots: Not generated (IGV not installed or no high-confidence variants found)" >> "$OUTPUT_DIR/report.txt"
fi

cat >> "$OUTPUT_DIR/report.txt" << EOF

For detailed methodology, see: DeNovoCNN_README.md
###############################################################################

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Analysis Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${BLUE}Results saved to: $OUTPUT_DIR${NC}"
echo -e "${BLUE}View the report: cat $OUTPUT_DIR/report.txt${NC}"
echo -e "${BLUE}Top variants: head -n 5 $OUTPUT_DIR/final_ranked_variants.csv${NC}"
if [[ -d "$SNAPSHOT_DIR" ]]; then
    echo -e "${BLUE}IGV snapshots: ls $SNAPSHOT_DIR${NC}"
fi

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
echo -e "${BLUE}IGV Snapshot directory: $IGV_INSTALLATION_DIR${NC}"
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
echo -e "  - IGV Snapshot Automator (installed at: $IGV_INSTALLATION_DIR)"
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

#!/bin/bash

###############################################################################
# DeNovoCNN Installation Script
# 
# This script installs DeNovoCNN using either Docker or conda
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

# Default parameters
INSTALL_DIR=""
USE_CONDA=true  # Default to conda (recommended)
CONDA_PREFIX=""
CONDA_ENV_NAME="denovocnn_env"
DOCKER_IMAGE="gelana/denovocnn:1.0"

###############################################################################
# Help Function
###############################################################################
print_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Installation Options:"
    echo "  --use-conda             Use conda instead of Docker (recommended)"
    echo "  --install-dir PATH      Directory for DeNovoCNN installation (default: ./DeNovoCNN)"
    echo "  --conda-prefix PATH     Exact conda environment location (default: install_dir/env)"
    echo "  --conda-env NAME        Conda environment name (only if conda-prefix not set)"
    echo "  --docker-image IMAGE    Docker image name (default: gelana/denovocnn:1.0)"
    echo "  --help                  Show this help message"
    echo ""
    echo "Example (Conda - Recommended):"
    echo "  $0 --use-conda --install-dir /Users/matteozoia/tools/DeNovoCNN"
    echo ""
    echo "Example (Docker):"
    echo "  $0"
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
    echo "  $0 --install-dir /Users/matteozoia/tools/DeNovoCNN"
    echo ""
    echo -e "${BLUE}Full example with conda:${NC}"
    echo "  $0 --use-conda --install-dir /Users/matteozoia/tools/DeNovoCNN"
    echo ""
    echo -e "${YELLOW}For more options, run: $0 --help${NC}"
    exit 1
fi

###############################################################################
# Set default conda prefix if not specified
###############################################################################
if [[ "$USE_CONDA" = true && -z "$CONDA_PREFIX" ]]; then
    CONDA_PREFIX="$INSTALL_DIR/env"
    echo -e "${BLUE}Conda environment will be installed at: $CONDA_PREFIX${NC}"
fi

###############################################################################
# Installation
###############################################################################
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}DeNovoCNN Installation${NC}"
echo -e "${BLUE}========================================${NC}"

if [[ "$USE_CONDA" = true ]]; then
    echo -e "${BLUE}Setting up conda installation...${NC}"
    
    # Check conda installation
    if ! command -v conda &> /dev/null; then
        echo -e "${RED}Error: Conda is not installed. Please install conda first.${NC}"
        echo "Visit: https://docs.conda.io/en/latest/miniconda.html"
        exit 1
    fi
    
    # Clone DeNovoCNN repository if not exists
    if [[ ! -d "$INSTALL_DIR" ]]; then
        echo -e "${BLUE}Cloning DeNovoCNN to $INSTALL_DIR...${NC}"
        git clone https://github.com/Genome-Bioinformatics-RadboudUMC/DeNovoCNN.git "$INSTALL_DIR"
    else
        echo -e "${GREEN}DeNovoCNN already installed at $INSTALL_DIR${NC}"
    fi
    
    # Create conda environment if not exists
    if [[ -n "$CONDA_PREFIX" ]]; then
        # Use prefix (specific path)
        if [[ ! -d "$CONDA_PREFIX" ]]; then
            echo -e "${BLUE}Creating conda environment at: $CONDA_PREFIX...${NC}"
            cd "$INSTALL_DIR"
            conda env create -f environment.yml -p "$CONDA_PREFIX"
            cd - > /dev/null
            echo -e "${GREEN}Conda environment created successfully at: $CONDA_PREFIX${NC}"
        else
            echo -e "${GREEN}Conda environment already exists at: $CONDA_PREFIX${NC}"
        fi
    else
        # Use environment name
        if ! conda env list | grep -q "^${CONDA_ENV_NAME} "; then
            echo -e "${BLUE}Creating conda environment: $CONDA_ENV_NAME...${NC}"
            cd "$INSTALL_DIR"
            conda env create -f environment.yml --name "$CONDA_ENV_NAME"
            cd - > /dev/null
            echo -e "${GREEN}Conda environment $CONDA_ENV_NAME created successfully${NC}"
        else
            echo -e "${GREEN}Conda environment $CONDA_ENV_NAME already exists${NC}"
        fi
    fi
    
    # Save installation configuration
    cat > "$INSTALL_DIR/install_config.sh" << EOF
#!/bin/bash
export INSTALL_DIR="$INSTALL_DIR"
export USE_CONDA=true
export CONDA_PREFIX="$CONDA_PREFIX"
export CONDA_ENV_NAME="$CONDA_ENV_NAME"
EOF
    
else
    echo -e "${BLUE}Setting up Docker installation...${NC}"
    
    # Check Docker installation
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Docker is not installed. Please install Docker first.${NC}"
        echo "Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    # Pull Docker Image
    echo -e "${BLUE}Pulling DeNovoCNN Docker image: $DOCKER_IMAGE...${NC}"
    docker pull "$DOCKER_IMAGE"
    echo -e "${GREEN}Docker image pulled successfully${NC}"
    
    # Save installation configuration
    cat > "$INSTALL_DIR/install_config.sh" << EOF
#!/bin/bash
export INSTALL_DIR="$INSTALL_DIR"
export USE_CONDA=false
export DOCKER_IMAGE="$DOCKER_IMAGE"
EOF
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Installation directory: $INSTALL_DIR${NC}"
if [[ "$USE_CONDA" = true ]]; then
    if [[ -n "$CONDA_PREFIX" ]]; then
        echo -e "${BLUE}Conda environment: $CONDA_PREFIX${NC}"
    else
        echo -e "${BLUE}Conda environment: $CONDA_ENV_NAME${NC}"
    fi
else
    echo -e "${BLUE}Docker image: $DOCKER_IMAGE${NC}"
fi
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Review the documentation: cat DeNovoCNN_README.md"
echo -e "2. Run analysis pipeline: ./run_denovocnn_pipeline.sh --help"
echo ""
echo -e "${GREEN}Ready to use!${NC}"

#!/bin/bash
set -euo pipefail

# ── CuCLARK Minimum Working Example ──────────────────────────────────────
# Downloads 3 small viral genomes from NCBI, generates simulated reads,
# runs cuCLARK-l classification, and shows a summary.
#
# Usage (inside Docker container):
#   bash /opt/cuclark/mwe/run_mwe.sh [DATA_DIR]
#
# Default DATA_DIR: /data/mwe

DATA_DIR="${1:-/data/mwe}"

echo "============================================================"
echo "  CuCLARK Minimum Working Example"
echo "  Output directory: $DATA_DIR"
echo "============================================================"
echo ""

mkdir -p "$DATA_DIR/genomes" "$DATA_DIR/db"

# ── Step 1: Download 3 small viral genomes ──────────────────────────────
echo "[1/5] Downloading viral genomes from NCBI RefSeq..."

download_genome() {
	local name="$1"
	local url="$2"
	local outfile="$DATA_DIR/genomes/${name}.fna"

	if [ -f "$outfile" ]; then
		echo "  Already exists: $name"
		return 0
	fi

	echo "  Downloading: $name"
	if command -v wget &>/dev/null; then
		wget -q "$url" -O "${outfile}.gz"
	elif command -v curl &>/dev/null; then
		curl -sfL "$url" -o "${outfile}.gz"
	else
		echo "  ERROR: neither wget nor curl found"
		return 1
	fi

	if [ ! -s "${outfile}.gz" ]; then
		echo "  ERROR: download failed or file is empty for $name"
		rm -f "${outfile}.gz"
		return 1
	fi

	gzip -df "${outfile}.gz"

	if [ ! -s "$outfile" ]; then
		echo "  ERROR: decompression failed for $name"
		return 1
	fi
}

# PhiX174 (~5kb)
download_genome "phiX174" \
	"https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/819/615/GCF_000819615.1_ViralProj14015/GCF_000819615.1_ViralProj14015_genomic.fna.gz"

# Lambda phage (~48kb)
download_genome "lambda" \
	"https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/840/245/GCF_000840245.1_ViralProj14204/GCF_000840245.1_ViralProj14204_genomic.fna.gz"

# T4 phage (~169kb)
download_genome "T4" \
	"https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/845/945/GCF_000845945.1_ViralProj14520/GCF_000845945.1_ViralProj14520_genomic.fna.gz"

echo "  Done."

# ── Step 2: Create targets file ─────────────────────────────────────────
echo "[2/5] Creating targets file..."

cat > "$DATA_DIR/targets.txt" <<EOF
$DATA_DIR/genomes/phiX174.fna	phiX174
$DATA_DIR/genomes/lambda.fna	lambda
$DATA_DIR/genomes/T4.fna	T4
EOF

echo "  Created targets.txt with 3 genomes."

# ── Step 3: Generate simulated reads ────────────────────────────────────
echo "[3/5] Generating simulated reads..."

generate_reads() {
	local genome="$1"
	local label="$2"
	local read_len=150
	local num_reads=50

	local seq
	seq=$(grep -v "^>" "$genome" | tr -d '\n\r ')
	local seq_len=${#seq}

	if [ "$seq_len" -lt "$read_len" ]; then
		echo "  WARN: $label genome too short ($seq_len bp), skipping"
		return
	fi

	local i=0
	while [ "$i" -lt "$num_reads" ]; do
		local max_start=$((seq_len - read_len))
		local start=$((RANDOM % max_start))
		local read_seq="${seq:$start:$read_len}"

		echo ">${label}_read_${i}"
		echo "$read_seq"
		i=$((i + 1))
	done
}

{
	generate_reads "$DATA_DIR/genomes/phiX174.fna" "phiX174"
	generate_reads "$DATA_DIR/genomes/lambda.fna" "lambda"
	generate_reads "$DATA_DIR/genomes/T4.fna" "T4"
} > "$DATA_DIR/reads.fa"

NUM_READS=$(grep -c "^>" "$DATA_DIR/reads.fa")
echo "  Generated $NUM_READS simulated reads."

# ── Step 4: Run classification ──────────────────────────────────────────
echo "[4/5] Running cuCLARK classification (auto-selecting variant)..."

cuclark classify \
	--reads "$DATA_DIR/reads.fa" \
	--output "$DATA_DIR/results" \
	--targets "$DATA_DIR/targets.txt" \
	--db-dir "$DATA_DIR/db/" \
	--metadata

# ── Step 5: Show summary ────────────────────────────────────────────────
echo ""
echo "[5/5] Classification results:"
echo ""

cuclark summary "$DATA_DIR/results.csv"

echo ""
echo "============================================================"
echo "  MWE complete!"
echo "  Results: $DATA_DIR/results.csv"
echo "  To view JSON: cuclark summary $DATA_DIR/results.csv --format json"
echo "  To view Krona: cuclark summary $DATA_DIR/results.csv --krona"
echo "============================================================"

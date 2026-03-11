#!/bin/bash
set -euo pipefail

# ── Real-world MWE for cuCLARK ──────────────────────────────────────────
# Demonstrates a realistic metagenomic classification workflow using
# uniques.fasta (pathogen reference genomes):
#   1. Splits uniques.fasta into per-accession target genomes
#   2. Simulates reads from one organism (E. coli K-12)
#   3. Builds a cuCLARK database from all targets
#   4. Classifies the reads and evaluates species-level accuracy
#
# The input FASTA contains these organisms:
#   NC_000913.3   Escherichia coli K-12 MG1655
#   NC_007795.1   Staphylococcus aureus NCTC 8325
#   NC_002516.2   Pseudomonas aeruginosa PAO1
#   NC_017564.1   Yersinia enterocolitica Y11
#   NC_017565.1   Yersinia enterocolitica Y11 plasmid pYV03
#   NZ_UHII01000002.1  Tsukamurella pulmonis NCTC13230
#   NZ_UHII01000001.1  Tsukamurella pulmonis NCTC13230
#   NZ_LR134352.1 Nocardia asteroides NCTC11293
#
# Usage (inside Docker container):
#   docker run --gpus all \
#     -v /path/to/uniques.fasta:/data/uniques.fasta \
#     cuclark bash /opt/cuclark/mwe/test_example_fasta.sh /data/mwe_test /data/uniques.fasta
#
# Default DATA_DIR: /data/mwe_test

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${1:-/data/mwe_test}"
FASTA="${2:-${FASTA:-$SCRIPT_DIR/uniques.fasta}}"

# Which accession to simulate reads from (ground truth)
READ_SOURCE="${READ_SOURCE:-NC_000913.3}"

# Tunable parameters
NUM_READS="${NUM_READS:-200}"
READ_LEN="${READ_LEN:-150}"

if [ ! -f "$FASTA" ]; then
	echo "ERROR: FASTA file not found at $FASTA"
	echo "       Provide the path as the second argument or set the FASTA env var."
	exit 1
fi

mkdir -p "$DATA_DIR/genomes" "$DATA_DIR/db"

echo "============================================================"
echo "  cuCLARK Real-World MWE"
echo "  Input FASTA:      $FASTA"
echo "  Output directory: $DATA_DIR"
echo "  Read source:      $READ_SOURCE"
echo "  Reads:            $NUM_READS × ${READ_LEN}bp"
echo "============================================================"
echo ""

# ── Step 1: Split FASTA into per-accession target files ────────────────
echo "[1/5] Splitting input FASTA into per-accession targets..."

rm -f "$DATA_DIR/genomes/"*.fna

awk -v out_dir="$DATA_DIR/genomes" '
/^>/ {
    if (outfile) close(outfile)
    acc = substr($1, 2)
    outfile = out_dir "/" acc ".fna"
    count++
}
outfile { print > outfile }
END { print count }
' "$FASTA" | read -r TARGET_COUNT || true

# Count what we got
TARGET_COUNT=$(ls "$DATA_DIR/genomes/"*.fna 2>/dev/null | wc -l | tr -d ' ')
echo "  Extracted $TARGET_COUNT target genomes:"
for f in "$DATA_DIR/genomes/"*.fna; do
	acc=$(basename "$f" .fna)
	size=$(wc -c < "$f" | tr -d ' ')
	echo "    $acc ($(( size / 1024 )) KB)"
done

# Verify read source exists
SOURCE_FASTA="$DATA_DIR/genomes/${READ_SOURCE}.fna"
if [ ! -f "$SOURCE_FASTA" ]; then
	echo ""
	echo "  ERROR: Read source accession $READ_SOURCE not found in input FASTA."
	echo "  Available accessions:"
	ls "$DATA_DIR/genomes/"*.fna | xargs -I{} basename {} .fna | sed 's/^/    /'
	exit 1
fi
echo ""

# ── Step 2: Simulate reads from one organism ───────────────────────────
echo "[2/5] Simulating $NUM_READS reads (${READ_LEN}bp) from $READ_SOURCE..."

READS_FILE="$DATA_DIR/reads.fa"

awk -v rl="$READ_LEN" -v num_reads="$NUM_READS" -v outfile="$READS_FILE" \
    -v src="$READ_SOURCE" '
BEGIN { seq = "" }
!/^>/ { seq = seq $0 }
END {
    srand(42)
    written = 0; attempts = 0; max_att = num_reads * 20
    seqlen = length(seq)
    while (written < num_reads && attempts < max_att) {
        attempts++
        start = int(rand() * (seqlen - rl)) + 1
        rd = substr(seq, start, rl)
        if (length(rd) < rl) continue
        n = gsub(/[Nn]/, "&", rd)
        if (n > rl * 0.1) continue
        printf ">read_%d src=%s pos=%d\n%s\n", written, src, start-1, rd > outfile
        written++
    }
    printf "  Generated %d reads from %s (%d bp genome)\n", written, src, seqlen
}' "$SOURCE_FASTA"

ACTUAL_READS=$(grep -c "^>" "$READS_FILE")
echo "  Total reads: $ACTUAL_READS"
echo ""

# ── Step 3: Create targets file ────────────────────────────────────────
echo "[3/5] Creating targets file..."

rm -rf "$DATA_DIR/db/"*
> "$DATA_DIR/targets.txt"
for f in "$DATA_DIR/genomes/"*.fna; do
	acc=$(basename "$f" .fna)
	echo "$f	$acc" >> "$DATA_DIR/targets.txt"
done

NUM_TGT=$(wc -l < "$DATA_DIR/targets.txt" | tr -d ' ')
echo "  Created targets.txt with $NUM_TGT targets"
echo ""

# ── Step 4: Run cuCLARK classification ─────────────────────────────────
echo "[4/5] Running cuCLARK classification..."

# Auto-detect resources
RAM_KB=$(awk '/MemTotal/{print $2}' /proc/meminfo 2>/dev/null || echo 0)
RAM_GB=$((RAM_KB / 1024 / 1024))

VRAM_MB=0
if command -v nvidia-smi &>/dev/null; then
	VRAM_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
fi
VRAM_GB=$((VRAM_MB / 1024))

echo "  System: ${RAM_GB} GB RAM, ${VRAM_GB} GB VRAM"

# Select variant
VARIANT=""
KMER=31
RESERVED_MB=400

if [ "$RAM_GB" -ge 48 ] && command -v cuCLARK &>/dev/null; then
	VARIANT="cuCLARK"
	LABEL="full"
elif command -v cuCLARK-l &>/dev/null; then
	VARIANT="cuCLARK-l"
	LABEL="light"
	KMER=27
	RESERVED_MB=300
elif command -v cuCLARK &>/dev/null; then
	VARIANT="cuCLARK"
	LABEL="full (forced, may OOM)"
fi

# Calculate batches from VRAM
if [ "$VRAM_MB" -gt 0 ]; then
	USABLE_VRAM_MB=$((VRAM_MB - RESERVED_MB))
	[ "$USABLE_VRAM_MB" -le 0 ] && USABLE_VRAM_MB=512
	BATCHES=$(( (2048 + USABLE_VRAM_MB - 1) / USABLE_VRAM_MB ))
	[ "$BATCHES" -lt 1 ] && BATCHES=1
	[ "$BATCHES" -gt 16 ] && BATCHES=16
else
	BATCHES=4
fi

if [ -n "$VARIANT" ]; then
	echo "  Variant: $VARIANT ($LABEL), k=$KMER, batches=$BATCHES"
	echo ""
	$VARIANT -k "$KMER" \
		-T "$DATA_DIR/targets.txt" \
		-D "$DATA_DIR/db/" \
		-O "$READS_FILE" \
		-R "$DATA_DIR/results" \
		-n 1 -b "$BATCHES" -d 1
else
	echo "  SKIP: No cuCLARK binary found (not inside Docker container?)"
	echo ""
	echo "  Steps 1-3 passed. To run classification:"
	echo "    docker build -t cuclark ."
	echo "    docker run --gpus all \\"
	echo "      -v /path/to/uniques.fasta:/data/uniques.fasta \\"
	echo "      cuclark bash /opt/cuclark/mwe/test_example_fasta.sh"
	exit 0
fi

# ── Step 5: Evaluate results ───────────────────────────────────────────
echo ""
echo "[5/5] Evaluating classification results..."
echo ""

RESULTS_CSV="$DATA_DIR/results.csv"
if [ ! -f "$RESULTS_CSV" ]; then
	echo "  ERROR: Results file not found at $RESULTS_CSV"
	exit 1
fi

TOTAL=$(grep -cv "^#\|^Object" "$RESULTS_CSV" || true)
CLASSIFIED=$(awk -F',' '$4 != "NA" && !/^#/ && !/^Object/' "$RESULTS_CSV" | wc -l | tr -d ' ')
CORRECT=$(awk -F',' -v expected="$READ_SOURCE" \
	'$4 == expected && !/^#/ && !/^Object/' "$RESULTS_CSV" | wc -l | tr -d ' ')
UNCLASSIFIED=$((TOTAL - CLASSIFIED))

# Confidence stats
HIGH_CONF=$(awk -F',' '!/^#/ && !/^Object/ && $NF+0 >= 0.90' "$RESULTS_CSV" | wc -l | tr -d ' ')

echo "  Ground truth: all reads from $READ_SOURCE"
echo ""
echo "  Total reads:       $TOTAL"
echo "  Classified:        $CLASSIFIED ($(( CLASSIFIED * 100 / TOTAL ))%)"
echo "  Unclassified:      $UNCLASSIFIED"
echo "  Correct species:   $CORRECT / $CLASSIFIED ($(( CLASSIFIED > 0 ? CORRECT * 100 / CLASSIFIED : 0 ))%)"
echo "  High confidence:   $HIGH_CONF (≥0.90)"

# Per-species breakdown
echo ""
echo "  Classification breakdown:"
awk -F',' '!/^#/ && !/^Object/ && $4 != "NA" {count[$4]++}
END {for (sp in count) printf "    %-40s %d\n", sp, count[sp]}' "$RESULTS_CSV" | sort -t' ' -k2 -rn

echo ""
if [ "$CORRECT" -eq "$CLASSIFIED" ] && [ "$CLASSIFIED" -gt 0 ]; then
	echo "  PASS: All classified reads correctly assigned to $READ_SOURCE"
elif [ "$CLASSIFIED" -gt 0 ] && [ "$CORRECT" -gt $((CLASSIFIED * 90 / 100)) ]; then
	echo "  PASS: >90% of classified reads correctly assigned"
else
	echo "  WARN: Classification accuracy lower than expected"
fi

echo ""
echo "============================================================"
echo "  MWE complete!"
echo "  References:  $TARGET_COUNT genomes from uniques.fasta"
echo "  Reads:       $ACTUAL_READS reads from $READ_SOURCE"
echo "  Results:     $RESULTS_CSV"
echo "============================================================"

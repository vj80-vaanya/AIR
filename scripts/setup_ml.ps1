# setup_ml.ps1 — Full ML pipeline: download → convert → build C vocab
# Run from the project root: .\scripts\setup_ml.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "`n=== AI Phone Security — ML Setup ===" -ForegroundColor Cyan
Write-Host "Working dir: $(Get-Location)"

# ── 1. Python check ──────────────────────────────────────────────────────────
Write-Host "`n[1/4] Checking Python..." -ForegroundColor Yellow
$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) { Write-Error "Python not found. Install Python 3.10+ and add to PATH."; exit 1 }
$ver = python --version
Write-Host "      $ver"

# ── 2. Install requirements ───────────────────────────────────────────────────
Write-Host "`n[2/4] Installing Python requirements..." -ForegroundColor Yellow
python -m pip install --upgrade pip --quiet
python -m pip install -r scripts\requirements_convert.txt

# ── 3. Convert model ──────────────────────────────────────────────────────────
Write-Host "`n[3/4] Converting HuggingFace model to TFLite..." -ForegroundColor Yellow
python scripts\convert_model.py
if ($LASTEXITCODE -ne 0) { Write-Error "Model conversion failed."; exit 1 }

# ── 4. Build C vocab ──────────────────────────────────────────────────────────
Write-Host "`n[4/4] Generating C vocabulary table..." -ForegroundColor Yellow
python scripts\build_c_vocab.py
if ($LASTEXITCODE -ne 0) { Write-Error "Vocab build failed."; exit 1 }

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host "`n=== Done ===" -ForegroundColor Green
Write-Host "Generated files:"

$files = @(
    "assets\models\text_classifier.tflite",
    "assets\models\text_classifier_f16.tflite",
    "assets\data\vocab.txt",
    "assets\data\tokenizer_config.json",
    "assets\data\model_meta.json",
    "native\src\vocab_table.c",
    "native\include\vocab_table.h"
)

foreach ($f in $files) {
    if (Test-Path $f) {
        $size = (Get-Item $f).Length
        $kb   = [math]::Round($size / 1024, 1)
        Write-Host "  OK  $f  ($kb KB)" -ForegroundColor Green
    } else {
        Write-Host "  MISSING  $f" -ForegroundColor Red
    }
}

Write-Host "`nNext: rebuild the C engine with TFLite enabled:" -ForegroundColor Cyan
Write-Host "  cmake -S native -B native/build -DENABLE_TFLITE=ON -DTFLITE_ROOT=<path>"
Write-Host "  cmake --build native/build -j4"

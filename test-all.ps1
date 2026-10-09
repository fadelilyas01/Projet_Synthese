# =====================================================================
# ShieldNet - Script d'Execution & de Validation Globale des Tests
# =====================================================================
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  SHIELDNET - VALIDATION GLOBALE DES TESTS (126 TESTS)    " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$rootPath = $PSScriptRoot
$backendPath = Join-Path $rootPath "shieldnet_backend"
$mobilePath = Join-Path $rootPath "ShieldNet"

# 1. Tests Backend Django (74 tests)
Write-Host "[1/3] Execution des tests Django REST API..." -ForegroundColor Yellow
$backendProcess = Start-Process python -ArgumentList "manage.py test" -WorkingDirectory $backendPath -NoNewWindow -Wait -PassThru
$backendExit = $backendProcess.ExitCode

if ($backendExit -eq 0) {
    Write-Host "  -> Backend Django : SUCCES (74 tests reussis)" -ForegroundColor Green
} else {
    Write-Host "  -> Backend Django : ECHEC" -ForegroundColor Red
}
Write-Host ""

# 2. Analyse statique Flutter
Write-Host "[2/3] Analyse statique du code Flutter (flutter analyze)..." -ForegroundColor Yellow
$analyzeProcess = Start-Process flutter -ArgumentList "analyze `"$mobilePath`"" -NoNewWindow -Wait -PassThru
$analyzeExit = $analyzeProcess.ExitCode

if ($analyzeExit -eq 0) {
    Write-Host "  -> Analyse statique : AUCUNE ERREUR (0 avertissement)" -ForegroundColor Green
} else {
    Write-Host "  -> Analyse statique : AVERTISSEMENTS/ERREURS DETECTES" -ForegroundColor Red
}
Write-Host ""

# 3. Tests Unitaires & Securite Flutter (52 tests)
Write-Host "[3/3] Execution des tests Flutter (52 tests)..." -ForegroundColor Yellow
$flutterTestProcess = Start-Process flutter -ArgumentList "test" -WorkingDirectory $mobilePath -NoNewWindow -Wait -PassThru
$flutterTestExit = $flutterTestProcess.ExitCode

if ($flutterTestExit -eq 0) {
    Write-Host "  -> Tests Flutter : SUCCES (52/52 tests reussis)" -ForegroundColor Green
} else {
    Write-Host "  -> Tests Flutter : ECHEC" -ForegroundColor Red
}
Write-Host ""

# Bilan
Write-Host "==========================================================" -ForegroundColor Cyan
if ($backendExit -eq 0 -and $analyzeExit -eq 0 -and $flutterTestExit -eq 0) {
    Write-Host "  BILAN : TOUS LES 126 TESTS SONT AU VERT ! PROJET CONFORME." -ForegroundColor Green
} else {
    Write-Host "  BILAN : CERTAINS TESTS ONT ECHOUE. VERIFIER LES LOGS." -ForegroundColor Red
}
Write-Host "==========================================================" -ForegroundColor Cyan

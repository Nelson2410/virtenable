<#
.SYNOPSIS
Script de Rollback : Restauration des paramètres de sécurité d'origine.

.DESCRIPTION
Ce script annule toutes les modifications précédentes en réactivant VBS,
Credential Guard, l'isolation du noyau (HVCI) et les fonctionnalités Hyper-V natives.

.NOTES
Exécution obligatoire en tant qu'Administrateur. Un redémarrage est requis après exécution.
#>

# 1. ÉLÉVATION DES PRIVILÈGES
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdmin) {
    Write-Error "Ce script doit impérativement être exécuté dans une console PowerShell en tant qu'ADMINISTRATEUR."
    Exit
}

Write-Host "=== Restauration des paramètres de sécurité et d'hyperviseur d'origine ===" -ForegroundColor Cyan

# 2. RESTAURATION DU REGISTRE WINDOWS (RÉACTIVATION DE VBS & CREDENTIAL GUARD)
$RegistryPathDeviceGuard = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
$RegistryPathLsa = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
$RegistryPathHvci = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"

Write-Host "`n[1/3] Restauration des clés de Registre..." -ForegroundColor Yellow

# Réactivation des commutateurs globaux VBS à 1 (Activé par défaut sous Windows 11)
if (Test-Path $RegistryPathDeviceGuard) {
    New-ItemProperty -Path $RegistryPathDeviceGuard -Name "EnableVirtualizationBasedSecurity" -Value 1 -PropertyType DWORD -Force | Out-Null
    New-ItemProperty -Path $RegistryPathDeviceGuard -Name "EnabledVirtualizationSecurityBased" -Value 1 -PropertyType DWORD -Force | Out-Null
    Write-Host "  -> Commutateurs globaux VBS réactivés (1)." -ForegroundColor Green
}

# Réactivation de la politique Credential Guard (LsaCfgFlags à 1)
if (Test-Path $RegistryPathLsa) {
    New-ItemProperty -Path $RegistryPathLsa -Name "LsaCfgFlags" -Value 1 -PropertyType DWORD -Force | Out-Null
    Write-Host "  -> Configuration Credential Guard (LsaCfgFlags) réactivée (1)." -ForegroundColor Green
}

# Réactivation de l'intégrité de la mémoire (HVCI / Isolation du noyau)
if (Test-Path $RegistryPathHvci) {
    New-ItemProperty -Path $RegistryPathHvci -Name "Enabled" -Value 1 -PropertyType DWORD -Force | Out-Null
    Write-Host "  -> Isolation du noyau / Intégrité de la mémoire réactivée (1)." -ForegroundColor Green
}

# 3. RÉACTIVATION DES COMPOSANTS HYPER-V (PLATEFORME DE MICROSOFT)
Write-Host "`n[2/3] Réactivation des fonctionnalités d'hyperviseur Windows..." -ForegroundColor Yellow

# Liste des modules Windows à réinstaller pour restaurer l'état d'origine
$FeaturesToEnable = @(
    "VirtualMachinePlatform",
    "HyperVPlatform",
    "Microsoft-Hyper-V"
)

foreach ($Feature in $FeaturesToEnable) {
    Write-Host "  -> Installation du composant : $Feature..." -ForegroundColor Gray
    Dism /online /Enable-Feature /FeatureName:$Feature /NoRestart | Out-Null
}

Write-Host "  -> Fonctionnalités Windows d'hyperviseur réinstallées." -ForegroundColor Green

# 4. FINALISATION ET DEMANDE DE REDÉMARRAGE
Write-Host "`n[3/3] Restauration terminée avec succès !" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------------"
Write-Host "IMPORTANT : Un redémarrage complet est requis pour appliquer la sécurité."
Write-Host "Note : Après le reboot, la virtualisation imbriquée dans VMware sera bridée."
Write-Host "----------------------------------------------------------------------"

$Reboot = Read-Host "Voulez-vous redémarrer votre ordinateur immédiatement ? (O/N)"
if ($Reboot -eq "O" -or $Reboot -eq "o") {
    Write-Host "Redémarrage du système en cours..." -ForegroundColor Magenta
    Restart-Computer -Force
}
else {
    Write-Host "Pensez à redémarrer manuellement pour appliquer le retour à la normale." -ForegroundColor Yellow
}
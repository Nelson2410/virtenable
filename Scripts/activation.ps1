<#
.SYNOPSIS
Automatisation du débridage CPU pour les labs nécessitant de la virtualisation imbriquée.

.DESCRIPTION
Ce script désactive proprement la sécurité basée sur la virtualisation (VBS),
Credential Guard, l'isolation du noyau (HVCI), ainsi que l'hyperviseur natif
Hyper-V pour libérer les extensions Intel VT-x / AMD-V au profit de VMware Workstation.

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

Write-Host "=== Début de la configuration du système pour le Lab VMware (Proxmox / EVE-NG) ===" -ForegroundColor Cyan

# 2. CONFIGURATION DU REGISTRE WINDOWS (DÉSACTIVATION DE VBS & VARIANTES)
$RegistryPathDeviceGuard = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
$RegistryPathLsa = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
$RegistryPathHvci = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"

Write-Host "`n[1/3] Modification des clés de Registre..." -ForegroundColor Yellow

# Nettoyage d'un éventuel registre orphelin (s'il existe)
if (Get-ItemProperty -Path $RegistryPathDeviceGuard -Name "Nouvelle Valeur #1" -ErrorAction SilentlyContinue) {
    Remove-ItemProperty -Path $RegistryPathDeviceGuard -Name "Nouvelle Valeur #1" -Force
    Write-Host "  -> Clé résiduelle 'Nouvelle Valeur #1' détectée et supprimée." -ForegroundColor Gray
}

# Gestion et désactivation des deux variantes de clés VBS connues
if (-not (Test-Path $RegistryPathDeviceGuard)) {
    New-Item -Path $RegistryPathDeviceGuard -Force | Out-Null
}

New-ItemProperty -Path $RegistryPathDeviceGuard -Name "EnableVirtualizationBasedSecurity" -Value 0 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path $RegistryPathDeviceGuard -Name "EnabledVirtualizationSecurityBased" -Value 0 -PropertyType DWORD -Force | Out-Null
Write-Host "  -> Les commutateurs globaux VBS (variantes incluses) ont été positionnés à 0." -ForegroundColor Green

# Désactivation des indicateurs de politique Credential Guard (LsaCfgFlags à 0)
New-ItemProperty -Path $RegistryPathLsa -Name "LsaCfgFlags" -Value 0 -PropertyType DWORD -Force | Out-Null
Write-Host "  -> Configuration Credential Guard (LsaCfgFlags) positionnée à 0." -ForegroundColor Green

# Désactivation de l'intégrité de la mémoire (HVCI / Isolation du noyau)
if (-not (Test-Path $RegistryPathHvci)) {
    New-Item -Path $RegistryPathHvci -Force | Out-Null
}

New-ItemProperty -Path $RegistryPathHvci -Name "Enabled" -Value 0 -PropertyType DWORD -Force | Out-Null
Write-Host "  -> Isolation du noyau / Intégrité de la mémoire configurée sur Désactivé (0)." -ForegroundColor Green

# 3. DÉSACTIVATION DES COMPOSANTS HYPER-V
Write-Host "`n[2/3] Désactivation des fonctionnalités et hyperviseurs Windows conflictuels..." -ForegroundColor Yellow

$FeaturesToDisable = @("Microsoft-Hyper-V", "HyperVPlatform", "VirtualMachinePlatform")
foreach ($Feature in $FeaturesToDisable) {
    Write-Host "  -> Vérification et suppression du composant : $Feature..." -ForegroundColor Gray
    Dism /online /Disable-Feature /FeatureName:$Feature /NoRestart | Out-Null
}

Write-Host "  -> Fonctionnalités Windows d'hyperviseur désactivées." -ForegroundColor Green

# 4. FINALISATION ET DEMANDE DE REDÉMARRAGE
Write-Host "`n[3/3] Configuration terminée avec succès !" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------------"
Write-Host "IMPORTANT : Un redémarrage complet est requis pour libérer le processeur."
Write-Host "----------------------------------------------------------------------"

$Reboot = Read-Host "Voulez-vous redémarrer votre ordinateur immédiatement ? (O/N)"
if ($Reboot -eq "O" -or $Reboot -eq "o") {
    Write-Host "Redémarrage du système en cours..." -ForegroundColor Magenta
    Restart-Computer -Force
}
else {
    Write-Host "Pensez à redémarrer manuellement avant de lancer VMware Workstation." -ForegroundColor Yellow
}
: <<'WINDOWS_BATCH'
@echo off
setlocal DisableDelayedExpansion
set "CHATISEN_SETUP_FILE=%~f0"
set "CHATISEN_SETUP_SKIP_WORKER="
if not "%~2"=="" goto usage_error
if "%~1"=="--help" goto usage
if "%~1"=="--sans-ia" set "CHATISEN_SETUP_SKIP_WORKER=1"
if not "%~1"=="" if not defined CHATISEN_SETUP_SKIP_WORKER goto usage_error
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -Command "$ErrorActionPreference = 'Stop'; $source = [IO.File]::ReadAllText($env:CHATISEN_SETUP_FILE); $code = [regex]::Match($source, '(?ms)^# BEGIN WINDOWS POWERSHELL\r?\n(.*?)^# END WINDOWS POWERSHELL\r?$'); if (-not $code.Success) { throw 'Bloc Windows introuvable.' }; & ([scriptblock]::Create($code.Groups[1].Value))"
exit /b %ERRORLEVEL%
:usage_error
echo Argument inconnu. Utiliser --help.
exit /b 2
:usage
echo Usage : %~nx0 [--sans-ia]
echo Installer les dependances dans le depot ChatISEN.
exit /b 0
WINDOWS_BATCH

# Linux. Garder ce fichier en ASCII avec des fins de ligne LF pour cmd.exe et Bash.
set -euo pipefail

fail() { printf 'Erreur : %s\n' "$*" >&2; exit 1; }

case "${1:-}" in
  --help) printf 'Usage : bash %s [--sans-ia]\nInstaller les dependances dans le depot ChatISEN.\n' "${0##*/}"; exit 0 ;;
  ''|--sans-ia) (( $# <= 1 )) || fail 'Utiliser --help.' ;;
  *) fail 'Argument inconnu. Utiliser --help.' ;;
esac
[[ $(uname -s) == Linux ]] || fail 'Cette commande Bash est prevue pour Linux.'
[[ -z ${SUDO_USER:-} ]] || fail 'Relancez le script sans sudo. Il le demandera pour les installations systeme.'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
project_dir="$script_dir"
if [[ ${script_dir##*/} == doc && ! -f $script_dir/apps/backend/package-lock.json ]]; then
  project_dir=$(dirname -- "$script_dir")
fi
backend="$project_dir/apps/backend"
frontend="$project_dir/apps/frontend"
worker="$project_dir/services/worker-qos"
[[ -f $backend/package-lock.json && -f $frontend/package-lock.json ]] ||
  fail 'Placer ce script a la racine du depot ChatISEN ou dans son dossier doc.'
if [[ ${1:-} != --sans-ia && ! -f $worker/requirements-dev.txt ]]; then
  fail 'Fichier requirements-dev.txt du worker QoS introuvable.'
fi

user_bin="$HOME/.local/bin"
node_dir="${XDG_DATA_HOME:-$HOME/.local/share}/chatisen/node24"
export PATH="$user_bin:$PATH"
scratch=$(mktemp -d)
trap 'rm -f -- "$scratch"/*; rmdir -- "$scratch"' EXIT

as_root() {
  if (( EUID == 0 )); then
    "$@"
  else
    command -v sudo >/dev/null || fail 'sudo est requis pour installer les paquets systeme.'
    sudo -- "$@"
  fi
}

install_linux_packages() {
  if command -v apt-get >/dev/null; then
    as_root apt-get update
    as_root env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l apt-get install -y --no-install-recommends "$@"
  elif command -v dnf >/dev/null; then
    as_root dnf install -y "$@"
  elif command -v pacman >/dev/null; then
    as_root pacman -S --needed --noconfirm "$@"
  elif command -v zypper >/dev/null; then
    as_root zypper --non-interactive install "$@"
  else
    fail "Gestionnaire de paquets inconnu. Installer $* puis relancer le script."
  fi
}

download() {
  curl --proto '=https' --proto-redir '=https' -fsSL --retry 3 -o "$2" "$1"
}

ensure_download_tools() {
  local -a required=()
  command -v curl >/dev/null || required+=(curl ca-certificates)
  if [[ ${1:-} == node ]]; then
    command -v tar >/dev/null || required+=(tar)
    command -v sha256sum >/dev/null || required+=(coreutils)
  fi
  if (( ${#required[@]} > 0 )); then install_linux_packages "${required[@]}"; fi
}

node_ready() {
  command -v npm >/dev/null &&
    node -e 'const [major, minor] = process.versions.node.split(".").map(Number); process.exit(major === 24 || major >= 26 || (major === 22 && minor >= 13) ? 0 : 1)' 2>/dev/null
}

if ! node_ready; then
  export PATH="$node_dir/bin:$PATH"
  if ! node_ready; then
    case "$(uname -m)" in
      x86_64) node_arch=x64 ;;
      aarch64|arm64) node_arch=arm64 ;;
      *) fail "L'installation automatique de Node.js exige Linux x86_64 ou ARM64." ;;
    esac
    ensure_download_tools node
    printf 'Installation de Node.js 24 LTS et npm...\n'
    node_release=https://nodejs.org/dist/latest-v24.x
    download "$node_release/SHASUMS256.txt" "$scratch/node-checksums"
    read -r checksum archive < <(awk -v arch="$node_arch" '$2 ~ "^node-v24\\.[0-9]+\\.[0-9]+-linux-" arch "\\.tar\\.gz$" {print $1, $2; exit}' "$scratch/node-checksums") ||
      fail 'Archive Node.js 24 introuvable.'
    version=${archive%%-linux-*}
    download "https://nodejs.org/dist/${version#node-}/$archive" "$scratch/$archive"
    (cd -- "$scratch"; printf '%s  %s\n' "$checksum" "$archive" | sha256sum -c -)
    mkdir -p -- "$node_dir"
    tar -xzf "$scratch/$archive" --strip-components=1 -C "$node_dir"
    mkdir -p -- "$user_bin"
    for tool in node npm npx; do
      if [[ ! -e $user_bin/$tool && ! -L $user_bin/$tool ]]; then
        ln -s -- "$node_dir/bin/$tool" "$user_bin/$tool"
      fi
    done
  fi
  node_ready || fail 'Node.js ou npm indisponible apres installation.'
  printf 'Node.js ChatISEN : %s/bin (ajouter %s au PATH si necessaire).\n' "$node_dir" "$user_bin"
fi

printf 'Installation des dependances npm...\n'
(cd -- "$frontend"; npm ci --include=dev)
(cd -- "$backend"; npm ci --include=dev)

if [[ ${1:-} != --sans-ia ]]; then
  python_env="$worker/.venv/bin/python"
  if [[ ! -e $worker/.venv && ! -L $worker/.venv ]]; then
    if python3.12 -m ensurepip --version >/dev/null 2>&1; then
      python3.12 -m venv "$worker/.venv"
    else
      if ! command -v uv >/dev/null; then
        ensure_download_tools
        download 'https://astral.sh/uv/0.13.10/install.sh' "$scratch/uv-install.sh"
        UV_UNMANAGED_INSTALL="$user_bin" sh "$scratch/uv-install.sh"
      fi
      uv venv --seed --python 3.12 "$worker/.venv"
    fi
  fi
  [[ -x $python_env && -f $worker/.venv/pyvenv.cfg ]] ||
    fail 'Environnement Python .venv inutilisable. Renommer ce dossier puis relancer.'
  "$python_env" -c 'import sys; sys.exit(0 if sys.prefix != sys.base_prefix and sys.version_info >= (3, 12) else 1)' ||
    fail 'Le worker exige Python 3.12 ou plus. Renommer son .venv puis relancer.'
  "$python_env" -m pip install --disable-pip-version-check -r "$worker/requirements-dev.txt"
fi

printf 'Dependances installees. Projet : %s\n' "$project_dir"
exit 0

: <<'POWERSHELL_PAYLOAD'
# BEGIN WINDOWS POWERSHELL
$scriptDir = Split-Path -Parent $env:CHATISEN_SETUP_FILE
$skipWorker = $env:CHATISEN_SETUP_SKIP_WORKER -eq '1'
$nodeDir = Join-Path $env:LOCALAPPDATA 'ChatISEN\node24'

function Invoke-Checked {
  param([string] $Program, [string[]] $Arguments)
  & $Program @Arguments
  if ($LASTEXITCODE -ne 0) { throw "$Program a retourne le code $LASTEXITCODE." }
}

function Update-ToolPath {
  $installed = @(
    [Environment]::GetEnvironmentVariable('Path', 'Machine')
    [Environment]::GetEnvironmentVariable('Path', 'User')
    "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
    "$env:ProgramFiles\WinGet\Links"
  )
  $env:Path = (@($env:Path -split ';') + @($installed -split ';') |
    Where-Object { $_ } | Select-Object -Unique) -join ';'
}

function Install-Uv {
  if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    if (Get-Command Add-AppxPackage -ErrorAction SilentlyContinue) {
      try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe'
        Update-ToolPath
      } catch { Write-Host 'Inscription App Installer indisponible sur ce poste.' }
    }
  }
  if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    throw 'WinGet est requis pour ce poste. Installer App Installer (Microsoft), puis relancer.'
  }
  Write-Host 'Installation de uv pour Python...'
  Invoke-Checked winget.exe @('install', '--id', 'astral-sh.uv', '--exact', '--source', 'winget',
    '--silent', '--disable-interactivity', '--accept-source-agreements', '--accept-package-agreements')
  Update-ToolPath
}

function Test-Node {
  if (-not (Get-Command node.exe -ErrorAction SilentlyContinue) -or
      -not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) { return $false }
  & node.exe -e "const [major, minor] = process.versions.node.split('.').map(Number); process.exit(major === 24 || major >= 26 || (major === 22 && minor >= 13) ? 0 : 1)"
  return ($LASTEXITCODE -eq 0)
}

function Set-UpNode {
  if (Test-Node) { return }
  $env:Path = "$nodeDir;$env:Path"
  if (-not (Test-Node)) {
    Write-Host 'Installation de Node.js 24 LTS et npm...'
    $arch = switch ($env:PROCESSOR_ARCHITEW6432, $env:PROCESSOR_ARCHITECTURE | Where-Object { $_ } | Select-Object -First 1) {
      'AMD64' { 'x64' }
      'ARM64' { 'arm64' }
      default { throw 'Architecture Windows prise en charge : x64 ou ARM64.' }
    }
    $release = 'https://nodejs.org/dist/latest-v24.x'
    $hashes = (Invoke-WebRequest -UseBasicParsing "$release/SHASUMS256.txt").Content
    $entry = [regex]::Match($hashes, "(?m)^([0-9a-f]{64})\s+(node-v24\.\d+\.\d+-win-$arch\.zip)\s*$")
    if (-not $entry.Success) { throw 'Archive Node.js 24 introuvable.' }
    $archiveName = $entry.Groups[2].Value
    $temp = Join-Path ([IO.Path]::GetTempPath()) ("chatisen-node-" + [guid]::NewGuid())
    [IO.Directory]::CreateDirectory($temp) | Out-Null
    try {
      $archive = Join-Path $temp $archiveName
      $version = ($archiveName -split '-win-', 2)[0].Substring(5)
      Invoke-WebRequest -UseBasicParsing "https://nodejs.org/dist/$version/$archiveName" -OutFile $archive
      if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $entry.Groups[1].Value) {
        throw 'Somme SHA256 Node.js incorrecte.'
      }
      Expand-Archive -LiteralPath $archive -DestinationPath $temp
      $expanded = Join-Path $temp ([IO.Path]::GetFileNameWithoutExtension($archiveName))
      [IO.Directory]::CreateDirectory($nodeDir) | Out-Null
      Get-ChildItem -LiteralPath $expanded -Force | Copy-Item -Destination $nodeDir -Recurse -Force
    } finally {
      [IO.Directory]::Delete($temp, $true)
    }
  }
  if (-not (Test-Node)) { throw 'Node.js ou npm indisponible apres installation.' }
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if ($nodeDir -notin ($userPath -split ';')) {
    $newPath = (@($nodeDir) + @($userPath -split ';') | Where-Object { $_ }) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
  }
  Write-Host "Node.js ChatISEN : $nodeDir (ouvrir un nouveau terminal apres installation)."
}

try {
  $projectDir = $scriptDir
  if ((Split-Path -Leaf $scriptDir) -eq 'doc' -and
      -not (Test-Path -LiteralPath (Join-Path $scriptDir 'apps\backend\package-lock.json') -PathType Leaf)) {
    $projectDir = Split-Path -Parent $scriptDir
  }
  $backend = Join-Path $projectDir 'apps\backend'
  $frontend = Join-Path $projectDir 'apps\frontend'
  $worker = Join-Path $projectDir 'services\worker-qos'
  $requirements = Join-Path $worker 'requirements-dev.txt'
  foreach ($app in @($frontend, $backend)) {
    if (-not (Test-Path -LiteralPath (Join-Path $app 'package-lock.json') -PathType Leaf)) {
      throw 'Placer ce script a la racine du depot ChatISEN ou dans son dossier doc.'
    }
  }
  if (-not $skipWorker -and -not (Test-Path -LiteralPath $requirements -PathType Leaf)) {
    throw 'Fichier requirements-dev.txt du worker QoS introuvable.'
  }
  Update-ToolPath
  Set-UpNode
  Write-Host 'Installation des dependances npm...'
  foreach ($app in @($frontend, $backend)) {
    Push-Location -LiteralPath $app
    try { Invoke-Checked npm.cmd @('ci', '--include=dev') } finally { Pop-Location }
  }

  if (-not $skipWorker) {
    $venv = Join-Path $worker '.venv'
    $pythonEnv = Join-Path $venv 'Scripts\python.exe'
    if (-not (Test-Path -LiteralPath $venv)) {
      $hasPython = $false
      if (Get-Command py.exe -ErrorAction SilentlyContinue) {
        & py.exe -3.12 -m ensurepip --version *> $null
        $hasPython = $LASTEXITCODE -eq 0
      }
      if ($hasPython) {
        Invoke-Checked py.exe @('-3.12', '-m', 'venv', $venv)
      } else {
        if (-not (Get-Command uv.exe -ErrorAction SilentlyContinue)) { Install-Uv }
        Invoke-Checked uv.exe @('venv', '--seed', '--python', '3.12', $venv)
      }
    }
    if (-not (Test-Path -LiteralPath $pythonEnv -PathType Leaf) -or
        -not (Test-Path -LiteralPath (Join-Path $venv 'pyvenv.cfg') -PathType Leaf)) {
      throw 'Environnement Python .venv inutilisable. Renommer ce dossier puis relancer.'
    }
    Invoke-Checked $pythonEnv @('-c', 'import sys; sys.exit(0 if sys.prefix != sys.base_prefix and sys.version_info >= (3, 12) else 1)')
    Invoke-Checked $pythonEnv @('-m', 'pip', 'install', '--disable-pip-version-check', '-r', $requirements)
  }
  Write-Host "Dependances installees. Projet : $projectDir"
} catch {
  [Console]::Error.WriteLine("Erreur : $($_.Exception.Message)")
  exit 1
}
# END WINDOWS POWERSHELL
POWERSHELL_PAYLOAD

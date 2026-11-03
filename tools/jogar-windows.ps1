# Starts the source project with the official Godot 4.7.2 Windows editor.
# This is a launcher, NOT a native exported game executable.
$ErrorActionPreference = 'Stop'

try {
    $Project = Split-Path -Parent $PSScriptRoot
    if (-not (Test-Path -LiteralPath (Join-Path $Project 'project.godot'))) {
        throw 'project.godot nao encontrado. Extraia o ZIP completo antes de iniciar.'
    }
    if (-not $env:LOCALAPPDATA) { throw 'LOCALAPPDATA nao esta definido.' }
    $ArchiveName = 'Godot_v4.7.2-stable_win64.exe.zip'
    $Expected = '731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953'
    $Url = 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip'
    $Cache = Join-Path $env:LOCALAPPDATA 'ComeToMe\Godot-4.7.2'
    $Editor = Join-Path $Cache 'Godot_v4.7.2-stable_win64.exe'
    $Console = Join-Path $Cache 'Godot_v4.7.2-stable_win64_console.exe'
    New-Item -ItemType Directory -Force -Path $Cache | Out-Null

    if (-not (Test-Path -LiteralPath $Editor)) {
        # An owner-supplied ZIP next to the project supports an offline install;
        # it must have the same official SHA-256 as an online download.
        $LocalArchive = Join-Path $Project $ArchiveName
        $Downloaded = Join-Path $Cache ($ArchiveName + '.download')
        $Archive = $LocalArchive
        if (-not (Test-Path -LiteralPath $LocalArchive)) {
            Write-Host 'A descarregar o Godot oficial 4.7.2 para Windows (~86 MB).'
            Write-Host 'Este passo necessita de Internet apenas na primeira utilizacao.'
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $Url -OutFile $Downloaded -UseBasicParsing
            $Archive = $Downloaded
        }
        $Actual = (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($Actual -ne $Expected) {
            if ($Archive -eq $Downloaded) { Remove-Item -LiteralPath $Downloaded -Force -ErrorAction SilentlyContinue }
            throw 'SHA-256 do ZIP do Godot nao corresponde ao valor oficial. O ficheiro nao foi executado.'
        }
        Write-Host 'SHA-256 oficial confirmado. A extrair o Godot...'
        # Expand-Archive requires a .zip extension even for a verified download.
        if ($Archive -eq $Downloaded) {
            $VerifiedZip = Join-Path $Cache $ArchiveName
            Move-Item -LiteralPath $Downloaded -Destination $VerifiedZip -Force
            $Archive = $VerifiedZip
        }
        Expand-Archive -LiteralPath $Archive -DestinationPath $Cache -Force
        if (-not (Test-Path -LiteralPath $Editor)) { throw 'O ZIP verificado nao contem o executavel esperado.' }
    }

    Write-Host 'A importar recursos do projeto; a primeira vez pode demorar alguns minutos...'
    $Importer = if (Test-Path -LiteralPath $Console) { $Console } else { $Editor }
    $QuotedProject = '"' + $Project + '"'
    $Import = Start-Process -FilePath $Importer -ArgumentList @('--headless', '--path', $QuotedProject, '--editor', '--import') -Wait -PassThru -NoNewWindow
    if ($Import.ExitCode -ne 0) { throw "A importacao do Godot falhou (codigo $($Import.ExitCode))." }
    Write-Host 'A iniciar Come To Me...'
    Start-Process -FilePath $Editor -ArgumentList @('--path', $QuotedProject) | Out-Null
    exit 0
} catch {
    Write-Host ''
    Write-Host ('ERRO: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}

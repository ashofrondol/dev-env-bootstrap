# ============================================================
# bootstrap.ps1 - Windows WSL2 자동 설치 + make 실행 부트스트랩
# 실행: PowerShell(관리자) 에서
#   powershell -ExecutionPolicy Bypass -File bootstrap.ps1
# ============================================================

$ErrorActionPreference = "Stop"
$ProjectDir  = $PSScriptRoot
$ResumeName  = "!ResumeDevBootstrap"
$RunOncePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"

# ---------- WSL2 설치 여부 감지 ----------
# wsl.exe 출력은 UTF-16LE 이므로 인코딩을 맞춰야 파싱 가능
function Test-Wsl2Ready {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { return $false }
    $prev = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::Unicode
        $list = & wsl.exe -l -v 2>&1 | Out-String
        if ([string]::IsNullOrWhiteSpace($list) -or
            $list -match 'no installed distributions') { return $false }
        return $true
    } finally { [Console]::OutputEncoding = $prev }
}

# ---------- 재부팅 후 재개 훅 등록 ----------
function Register-Resume {
    $cmd = "`"$PSHOME\powershell.exe`" -NoProfile -ExecutionPolicy Bypass -File `"$ProjectDir\bootstrap.ps1`""
    Set-ItemProperty -Path $RunOncePath -Name $ResumeName -Value $cmd
    Write-Host "[i] 재부팅 후 자동으로 부트스트랩을 재개합니다."
}

# ---------- 메인 로직 ----------
if (Test-Wsl2Ready) {
    Write-Host "[OK] WSL2가 이미 설치되어 있습니다. make setup 실행..."
    # 프로젝트 폴더를 /mnt/<드라이브> 경로로 변환하여 WSL 내부에서 실행
    # (C: 전용 하드코딩 대신 임의 드라이브 문자·대소문자 지원)
    $drive   = $ProjectDir.Substring(0,1).ToLower()
    $rest    = ($ProjectDir.Substring(2) -replace '\\','/')
    $wslPath = "/mnt/$drive$rest"
    wsl -- bash -lic "cd '$wslPath' && make setup"
}
else {
    Write-Host "[i] WSL2가 없습니다. 설치를 시작합니다 (재부팅 필요)..."
    Register-Resume
    wsl --install --no-launch
    wsl --set-default-version 2
    Write-Host "[i] 10초 후 재부팅합니다. 로그인하면 자동으로 이어집니다."
    Start-Sleep -Seconds 10
    Restart-Computer
}

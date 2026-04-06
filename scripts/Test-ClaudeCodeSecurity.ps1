#╔════════════════════════════════════════════════════════════════════════════════╗
#║                                                                                ║
#║   Test-ClaudeCodeSecurity.ps1                                                  ║
#║                                                                                ║
#╟────────────────────────────────────────────────────────────────────────────────╢
#║   Guillaume Plante <arsscriptum@proton.me>                                     ║
#║   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      ║
#╚════════════════════════════════════════════════════════════════════════════════╝


param(
    [Parameter(Position = 0, Mandatory = $true)] 
    [string] $ProjectsRoot
    [Parameter(Mandatory = $false)] 
    [int]$MaxDepth    = 19
)

try{
    $compromisedAxios = @('1.14.1', '0.30.4')
    $maliciousDep     = 'plain-crypto-js'
    $lockfileNames    = @('package-lock.json', 'yarn.lock', 'bun.lockb')
    $foundIssues      = [System.Collections.Generic.List[string]]::new()

    # ── 1. Claude Code installation check ────────────────────────────────────
    Write-Host "`n=== Claude Code Installation ===" -ForegroundColor Cyan

    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue

    if ($claudeCmd) {
        $version = & claude --version 2>&1
        Write-Host "[FOUND] Claude Code at: $($claudeCmd.Source)" -ForegroundColor Yellow
        Write-Host "        Version : $version"

        if ($claudeCmd.Source -like '*npm*' -or $claudeCmd.Source -like '*node_modules*') {
            Write-Host "[WARN]  Installed via npm. Switch to the native installer:" -ForegroundColor Yellow
            Write-Host "        curl -fsSL https://claude.ai/install.sh | bash"
            $foundIssues.Add("Claude Code installed via npm (use native installer instead)")
        } else {
            Write-Host "[OK]    Not npm-based install." -ForegroundColor Green
        }
    } else {
        Write-Host "[OK]    Claude Code not installed." -ForegroundColor Green
    }

    # ── 2. Lockfile scan across your projects ────────────────────────────────
    Write-Host "`n=== Scanning lockfiles under: $ProjectsRoot ===" -ForegroundColor Cyan

    $lockfiles = Get-ChildItem -Path $ProjectsRoot -Recurse -File -Include $lockfileNames -MaxDepth $MaxDepth -ErrorAction SilentlyContinue

    if (-not $lockfiles) {
        Write-Host "[OK]    No lockfiles found." -ForegroundColor Green
    }

    foreach ($lf in $lockfiles) {
        Write-Host "[SCAN]  $($lf.FullName)" -ForegroundColor Gray

        $content = Get-Content $lf.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        $clean = $true

        foreach ($ver in $compromisedAxios) {
            if ($content -match [regex]::Escape($ver)) {
                $msg   = "Compromised axios $ver in: $($lf.FullName)"
                $clean = $false
                Write-Host "[!!!]   $msg" -ForegroundColor Red
                $foundIssues.Add($msg)
            }
        }

        if ($content -match [regex]::Escape($maliciousDep)) {
            $msg   = "Malicious dep '$maliciousDep' in: $($lf.FullName)"
            $clean = $false
            Write-Host "[!!!]   $msg" -ForegroundColor Red
            $foundIssues.Add($msg)
        }

        if ($clean) {
            Write-Host "[OK]    Clean." -ForegroundColor Green
        }
    }

    # ── 3. Summary ───────────────────────────────────────────────────────────
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan

    if ($foundIssues.Count -eq 0) {
        Write-Host "[OK]    No issues found." -ForegroundColor Green
    } else {
        Write-Host "[!!!]   $($foundIssues.Count) issue(s) found:`n" -ForegroundColor Red
        foreach ($issue in $foundIssues) {
            Write-Host "        - $issue" -ForegroundColor Red
        }
        Write-Host "`n[ACTION REQUIRED]" -ForegroundColor Red
        Write-Host "  1. Treat the machine as fully compromised"
        Write-Host "  2. Rotate ALL credentials, tokens, and secrets immediately"
        Write-Host "  3. Consider a clean OS reinstall"
    }

    return $foundIssues

catch {
    Write-Error "$_"
}


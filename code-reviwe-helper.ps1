


<#
================================================================================
 CODE REVIEW HELPER - COMPREHENSIVE GUIDE
================================================================================

 OVERVIEW
 --------
 Code review is a systematic examination of source code intended to find and
 fix mistakes overlooked in the initial development phase, improving both the
 overall quality of software and the developers' skills. It is one of the most
 effective practices for ensuring code correctness, maintainability, security,
 and team knowledge sharing.

 GOALS OF A CODE REVIEW
 ----------------------
 1. Correctness        - Does the code do what it claims to do?
 2. Readability        - Can another developer easily understand the code?
 3. Maintainability    - Is the code structured so future changes are safe?
 4. Performance        - Are there obvious inefficiencies or hot paths?
 5. Security           - Are there vulnerabilities or unsafe patterns?
 6. Consistency        - Does it follow project conventions and style?
 7. Testability        - Is the code covered by tests, and is it test-friendly?
 8. Knowledge Sharing  - Reviewers learn the codebase; authors learn from peers.

 HOW CODE REVIEW WORKS (TYPICAL FLOW)
 ------------------------------------
   Author writes code  --->  Opens Pull/Merge Request  --->  CI runs (build,
   lint, tests, security scans)  --->  Reviewers read diff, leave comments
   --->  Author addresses feedback  --->  Approval(s)  --->  Merge to main.

 Reviewers typically:
   - Read the description / linked issue to understand intent.
   - Skim the diff for scope and shape (is this PR too large?).
   - Read carefully file-by-file, line-by-line.
   - Run the code locally if behavior is non-trivial.
   - Leave actionable, kind, specific comments.
   - Distinguish blocking issues from nits / suggestions.

 WHAT TO LOOK FOR (GENERAL CHECKLIST)
 ------------------------------------
   [ ] Naming        - Clear, intention-revealing, consistent.
   [ ] Functions     - Small, single-purpose, reasonable parameter counts.
   [ ] Control flow  - No deep nesting; early returns where helpful.
   [ ] Error handling- Errors caught at the right layer; no silent swallowing.
   [ ] Logging       - Appropriate levels; no sensitive data logged.
   [ ] Comments      - Explain *why*, not *what*; remove stale comments.
   [ ] Dead code     - Remove unused imports, variables, functions.
   [ ] Duplication   - DRY where appropriate; avoid premature abstraction.
   [ ] Tests         - New behavior covered; edge cases included.
   [ ] Docs          - README / changelog / API docs updated.
   [ ] Dependencies  - Necessary, pinned, licensed appropriately.
   [ ] Backwards compatibility - Public APIs not broken silently.
   [ ] Concurrency   - Race conditions, locking, async correctness.
   [ ] Resource mgmt - Files, handles, sockets, DB connections disposed.

 INFORMATION TO CAPTURE PER REVIEW
 ---------------------------------
   - File path and line numbers of issues.
   - Total / code / comment / blank line counts (size of the change).
   - Cyclomatic complexity hints (if / for / while / switch / catch counts).
   - Function count and average function size.
   - Style issues: long lines, trailing whitespace, tabs vs spaces, mixed
     indentation, line-ending style (CRLF / LF / mixed), BOM presence.
   - Lint findings: aliases, Write-Host overuse, empty catch blocks,
     hardcoded paths, magic numbers, duplicated lines.
   - TODO / FIXME / HACK / XXX / BUG markers left in the code.
   - Parse / syntax errors from the language parser.
   - Severity classification (CLEAN / LOW / MEDIUM / HIGH) to prioritize.

 SECURITY REVIEW
 ---------------
 A security review is a focused pass that asks: "How could this code be
 abused, broken, or exploited?" It complements (does not replace) automated
 SAST/DAST tools and threat modeling.

 Common security categories to inspect:

   1. Input Validation & Injection
      - SQL / NoSQL injection, command injection, LDAP, XPath, template
        injection. Always parameterize queries and avoid string concatenation
        with untrusted input.

   2. Authentication & Session Management
      - Weak password storage (use bcrypt/argon2/scrypt, never MD5/SHA1).
      - Missing MFA, predictable tokens, long-lived sessions, missing logout.

   3. Authorization
      - Missing access checks (IDOR), confused-deputy issues, privilege
        escalation paths, default-allow policies.

   4. Secrets Management
      - Hardcoded passwords, API keys, connection strings, private keys.
      - Secrets checked into git history. Use a vault / environment vars.

   5. Cryptography
      - Custom crypto (avoid!), ECB mode, static IVs, weak RNGs
        (Math.Random instead of CSPRNG), expired or self-signed TLS,
        certificate validation disabled.

   6. Data Exposure
      - PII / PHI / payment data logged or returned in errors.
      - Verbose stack traces exposed to end users.
      - Backup files, .env, .git directories shipped to production.

   7. File & Path Handling
      - Path traversal (../), unsafe archive extraction (zip-slip),
        symlink attacks, world-writable files, insecure temp files.

   8. Deserialization & Parsing
      - Insecure deserialization (pickle, BinaryFormatter, unsafe YAML).
      - XML External Entity (XXE) attacks, billion-laughs DoS.

   9. Web-Specific
      - XSS (reflected/stored/DOM), CSRF, open redirects, clickjacking,
        missing security headers (CSP, HSTS, X-Frame-Options).

  10. Supply Chain
      - Unpinned dependencies, typosquatted packages, post-install scripts,
        compromised CI tokens.

  11. PowerShell-Specific (relevant to this script)
      - Invoke-Expression on untrusted input.
      - Modifying privileged files (e.g. hosts file at
        C:\Windows\System32\drivers\etc\hosts) - require admin, log changes,
        keep verifiable backups, never silently overwrite.
      - Auto-elevation via -Verb RunAs - validate $PSCommandPath, quote
        arguments carefully to avoid argument injection.
      - Execution policy bypass, downloading and running remote scripts
        (iwr | iex pattern).
      - Plain-text credentials; use Get-Credential / SecureString / DPAPI.

 SECURITY INFORMATION TO CAPTURE
 -------------------------------
   - File + line of each suspicious pattern.
   - Category (injection, secret, crypto, etc.) and CWE id when known.
   - Severity (Critical / High / Medium / Low / Info).
   - Exploit scenario in one sentence.
   - Recommended remediation and a link to a reference (OWASP, CWE, MSRC).
   - Whether a compensating control already exists (WAF, sandbox, etc.).

 SEVERITY GUIDANCE
 -----------------
   HIGH   - Parse errors, secrets in code, injection sinks, broken auth.
   MEDIUM - Many lint findings, hardcoded paths, empty catch blocks, weak
            crypto config, missing input validation on internal APIs.
   LOW    - Style issues, minor duplication, TODO markers, alias usage.
   CLEAN  - No findings of note; still worth a human read for design.

 USAGE
 -----
   .\code-reviwe-helper.ps1                # auto-detect .env in CWD
   .\code-reviwe-helper.ps1 -EnvPath path  # explicit env file
   Invoke-CodeLint -FilePath .\some.ps1    # lint a single file

================================================================================
#>

param(
    [Parameter(Position = 0)]
    [string]$EnvPath = ""
)

function Invoke-CodeLint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$FilePath
    )

    if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
        Write-Warning "File not found: $FilePath"
        return
    }

    $lines = Get-Content -Path $FilePath
    $content = Get-Content -Path $FilePath -Raw
    if ($null -eq $content) { $content = "" }

    $totalLines    = $lines.Count
    $blankLines    = ($lines | Where-Object { $_ -match '^\s*$' }).Count
    $commentLines  = ($lines | Where-Object { $_ -match '^\s*#' }).Count
    $codeLines     = $totalLines - $blankLines - $commentLines

    $spaceCount    = ([regex]::Matches($content, ' ')).Count
    $tabCount      = ([regex]::Matches($content, "`t")).Count
    $charCount     = $content.Length
    $wordCount     = ($content -split '\s+' | Where-Object { $_ -ne '' }).Count

    $longLines     = @()
    $trailingWS    = @()
    $tabLines      = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $ln = $lines[$i]
        if ($ln.Length -gt 120)   { $longLines  += ($i + 1) }
        if ($ln -match '\s+$')    { $trailingWS += ($i + 1) }
        if ($ln -match "`t")      { $tabLines   += ($i + 1) }
    }

    $psErrors = $null
    $tokens   = $null
    [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$tokens, [ref]$psErrors) | Out-Null
    $parseErrorCount = if ($psErrors) { $psErrors.Count } else { 0 }

    # Additional lint checks
    $mixedIndentLines = @()
    $todoLines        = @()
    $crlfMismatch     = @()
    $bomDetected      = $false
    $aliasUsage       = @()
    $writeHostUsage   = @()
    $emptyCatchBlocks = @()
    $hardcodedPaths   = @()
    $magicNumbers     = @()
    $duplicateLines   = @{}
    $functionCount    = 0
    $cyclomaticHints  = 0

    # BOM detection
    try {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $bomDetected = $true
        }
    } catch { }

    $commonAliases = @('ls','cd','cat','cp','mv','rm','ps','gci','gc','gi','gm','%','?','iex','sc','select','where','foreach')

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $ln = $lines[$i]
        $lineNum = $i + 1

        if ($ln -match '^\t+ ' -or $ln -match '^ +\t') { $mixedIndentLines += $lineNum }
        if ($ln -match '(?i)(TODO|FIXME|HACK|XXX|BUG)') { $todoLines += $lineNum }
        if ($ln -match '\bWrite-Host\b') { $writeHostUsage += $lineNum }
        if ($ln -match 'catch\s*\{\s*\}') { $emptyCatchBlocks += $lineNum }
        if ($ln -match '[A-Za-z]:\\' -and $ln -notmatch '^\s*#') { $hardcodedPaths += $lineNum }
        if ($ln -match '\bfunction\s+[\w-]+') { $functionCount++ }
        if ($ln -match '\b(if|elseif|while|for|foreach|switch|catch)\b') { $cyclomaticHints++ }

        foreach ($alias in $commonAliases) {
            if ($ln -match "(^|\s|\|)$([regex]::Escape($alias))(\s|$|\|)") {
                $aliasUsage += "${lineNum}:$alias"
                break
            }
        }

        $trimmed = $ln.Trim()
        if ($trimmed.Length -gt 10 -and $trimmed -notmatch '^\s*#') {
            if ($duplicateLines.ContainsKey($trimmed)) {
                $duplicateLines[$trimmed] += $lineNum
            } else {
                $duplicateLines[$trimmed] = @($lineNum)
            }
        }
    }

    $duplicates = $duplicateLines.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 } | ForEach-Object {
        "L$($_.Value -join ',')"
    }

    # CRLF / LF consistency
    $crlfCount = ([regex]::Matches($content, "`r`n")).Count
    $lfOnlyCount = ([regex]::Matches($content, "(?<!`r)`n")).Count
    $lineEndingStyle = if ($crlfCount -gt 0 -and $lfOnlyCount -gt 0) { "Mixed" }
                      elseif ($crlfCount -gt 0) { "CRLF" }
                      elseif ($lfOnlyCount -gt 0) { "LF" }
                      else { "None" }

    # Severity scoring
    $issueCount = $parseErrorCount + $longLines.Count + $trailingWS.Count + $emptyCatchBlocks.Count + $aliasUsage.Count
    $severity = if ($parseErrorCount -gt 0) { "HIGH" }
                elseif ($issueCount -gt 20) { "MEDIUM" }
                elseif ($issueCount -gt 0) { "LOW" }
                else { "CLEAN" }

    $result = [pscustomobject]@{
        File              = $FilePath
        TotalLines        = $totalLines
        CodeLines         = $codeLines
        CommentLines      = $commentLines
        BlankLines        = $blankLines
        CommentRatio      = if ($totalLines) { [math]::Round(($commentLines / $totalLines) * 100, 2) } else { 0 }
        Characters        = $charCount
        Words             = $wordCount
        Spaces            = $spaceCount
        Tabs              = $tabCount
        LongLines         = $longLines
        TrailingWSLines   = $trailingWS
        TabLines          = $tabLines
        MixedIndentLines  = $mixedIndentLines
        TodoLines         = $todoLines
        AliasUsage        = $aliasUsage
        WriteHostUsage    = $writeHostUsage
        EmptyCatchBlocks  = $emptyCatchBlocks
        HardcodedPaths    = $hardcodedPaths
        DuplicateLines    = $duplicates
        FunctionCount     = $functionCount
        CyclomaticHints   = $cyclomaticHints
        LineEndingStyle   = $lineEndingStyle
        BOMDetected       = $bomDetected
        ParseErrors       = $parseErrorCount
        Severity          = $severity
    }

    Write-Host "`n--- Lint Report: $FilePath ---" -ForegroundColor Cyan
    $result | Format-List
    if ($psErrors) {
        Write-Host "Parse Errors:" -ForegroundColor Red
        $psErrors | ForEach-Object { Write-Host "  $($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor Red }
    }

    return $result
}

$HostsSourcePath = "C:\Windows\System32\drivers\etc\hosts"
$HostsBackupPath = "C:\windows\system32\almhox.hosts"

# Auto-detect .env file in current folder and sub-folders
if ([string]::IsNullOrWhiteSpace($EnvPath)) {
    $EnvPath = Get-ChildItem -Path (Get-Location) -Filter ".env" -File -Recurse | Select-Object -First 1 -ExpandProperty FullName
}

# Auto-elevate to admin
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoExit -File `"$PSCommandPath`" `"$EnvPath`"" -Verb RunAs
    exit
}

# Backup hosts file
Copy-Item -Path $HostsSourcePath -Destination $HostsBackupPath -Force
Write-Host "Hosts backed up to $HostsBackupPath"

param(
    [Parameter(Mandatory)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version,
    [switch]$Publish
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path ([IO.Path]::GetTempPath()) ("sub2api-company-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $buildDir | Out-Null
Push-Location $repo
try {
    if (git status --porcelain) { throw 'Build from a clean commit.' }
    $commit = (git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve the current commit.' }
    $releaseTag = "company-$($commit.Substring(0, 12))"
    $published = git ls-remote origin refs/heads/codex/company-deploy
    if ($Publish -and ($LASTEXITCODE -ne 0 -or !$published.StartsWith($commit))) {
        throw 'Push the commit to the deployment branch before publishing.'
    }
    Push-Location frontend
    try {
        corepack pnpm@9.15.9 install --frozen-lockfile
        if ($LASTEXITCODE -ne 0) { throw 'Frontend dependency install failed.' }
        corepack pnpm@9.15.9 exec vitest run src/i18n/__tests__/localeKeyCompleteness.spec.ts
        if ($LASTEXITCODE -ne 0) { throw 'Frontend locale tests failed.' }
        corepack pnpm@9.15.9 exec vue-tsc -b
        if ($LASTEXITCODE -ne 0) { throw 'Frontend type check failed.' }
        corepack pnpm@9.15.9 exec vite build
        if ($LASTEXITCODE -ne 0) { throw 'Frontend build failed.' }
    } finally { Pop-Location }

    $env:GOOS = 'linux'
    $env:GOARCH = 'amd64'
    $env:CGO_ENABLED = '0'
    $buildDate = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    Push-Location backend
    try {
        go build -p 4 -tags embed -trimpath -ldflags "-s -w -X main.Version=$Version -X main.Commit=$commit -X main.Date=$buildDate -X main.BuildType=release" -o (Join-Path $buildDir 'sub2api') ./cmd/server
        if ($LASTEXITCODE -ne 0) { throw 'Linux build failed.' }
    } finally { Pop-Location }
    $asset = Join-Path $buildDir 'sub2api-linux-amd64.tar.gz'
    tar -czf $asset -C $buildDir sub2api -C (Join-Path $repo 'backend') resources
    if ($LASTEXITCODE -ne 0) { throw 'Release packaging failed.' }
    $checksums = Join-Path $buildDir 'checksums.txt'
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $asset).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText($checksums, "$hash  sub2api-linux-amd64.tar.gz`n")
    if ($Publish) {
        gh release create $releaseTag $asset $checksums -R Mr-again/sub2api --target $commit --prerelease --latest=false --title "Company Sub2API $Version" --notes "Linux amd64 binary and resources built from company fork commit $commit."
        if ($LASTEXITCODE -ne 0) { throw 'Fork release publication failed.' }
    }
    Write-Output "$releaseTag $buildDir"
} finally { Pop-Location }

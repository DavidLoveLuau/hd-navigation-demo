$ErrorActionPreference = "Stop"

Write-Host "Checking formatting..."
stylua --check src GamePackages
if ($LASTEXITCODE -ne 0) {
	throw "StyLua found formatting differences. Run: stylua src GamePackages"
}

Write-Host "Linting Luau..."
selene src GamePackages
if ($LASTEXITCODE -ne 0) {
	throw "Selene reported lint errors."
}

Write-Host "Validating Rojo project..."
$temporaryBuild = Join-Path $env:TEMP "TheBestGame-validation.rbxlx"
rojo build TheBestGame.project.json --output $temporaryBuild
if ($LASTEXITCODE -ne 0) {
	throw "Rojo could not build the project."
}
Remove-Item -LiteralPath $temporaryBuild -Force

Write-Host "All checks passed."

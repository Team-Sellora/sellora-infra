# Sellora Service Template — Clone & Rename Guide

**Status:** Adopted · **Applies to:** creating any new .NET microservice from the
`Sellora.CoreService` reference template · **Related story:** US-E0-4 (CSP-54)

This guide explains how to copy the reference Core service template and rename it
for a new microservice (e.g. `Sellora.Product`, `Sellora.Inventory`). Every place
the template name appears is listed. Follow the manual steps, or use the script in
§6 which performs them all.

The template name is **`Sellora.CoreService`**. In the steps below, replace
`<NewName>` with your service's name (e.g. `Product`), so the new service becomes
`Sellora.Product`.

---

## 1. What the template contains

```
Sellora.CoreService.sln
src/
  Sellora.CoreService.Domain/          (+ .csproj)
  Sellora.CoreService.Application/     (+ .csproj)
  Sellora.CoreService.Infrastructure/  (+ .csproj)
  Sellora.CoreService.Api/             (+ .csproj, .http)
tests/
  Sellora.CoreService.Tests/           (+ .csproj)
global.json
```

The name `Sellora.CoreService` appears in:

- **File and folder names** — the `.sln`, the five project folders, their `.csproj`
  files, and the `.http` file.
- **File contents** — the `.sln` (project paths), every `.csproj` (project
  references), and every `.cs` file (`namespace` declarations and `using`
  statements).
- **Class names** — `CoreDbContext` in the Infrastructure project.
- **Config** — the SQLite connection string database name in `appsettings.json`.
- **Dockerfile** — not present in the template yet. When a Dockerfile is added
  (deployment epic), it will reference the `.Api` project path and must be renamed
  too; add that step here at that time.

---

## 2. Copy the template

Copy the whole template folder to a new location and name it for the new service.

```powershell
# From the folder that contains the template repo
Copy-Item -Recurse "sellora-organization" "sellora-<newname>"
cd "sellora-<newname>"

# Remove build artifacts and git history from the copy
Get-ChildItem -Recurse -Directory -Include bin,obj | Remove-Item -Recurse -Force
Remove-Item -Recurse -Force .git   # if present; re-init as a new repo
```

---

## 3. Rename files and folders

Rename every file/folder whose name contains `Sellora.CoreService` →
`Sellora.<NewName>`:

1. `Sellora.CoreService.sln` → `Sellora.<NewName>.sln`
2. `src/Sellora.CoreService.Domain/` → `src/Sellora.<NewName>.Domain/`
   - and `Sellora.CoreService.Domain.csproj` → `Sellora.<NewName>.Domain.csproj`
3. `src/Sellora.CoreService.Application/` → `src/Sellora.<NewName>.Application/`
   - and its `.csproj`
4. `src/Sellora.CoreService.Infrastructure/` → `src/Sellora.<NewName>.Infrastructure/`
   - and its `.csproj`
5. `src/Sellora.CoreService.Api/` → `src/Sellora.<NewName>.Api/`
   - and `Sellora.CoreService.Api.csproj`, `Sellora.CoreService.Api.http`
6. `tests/Sellora.CoreService.Tests/` → `tests/Sellora.<NewName>.Tests/`
   - and its `.csproj`

---

## 4. Replace the name inside all files

Replace every occurrence of the string `Sellora.CoreService` with
`Sellora.<NewName>` inside file contents. This covers:

- `.sln` — project names and relative paths
- every `.csproj` — `<ProjectReference>` paths
- every `.cs` — `namespace Sellora.CoreService.*` and `using Sellora.CoreService.*`
- the `.http` file

PowerShell, run from the new service's root:

```powershell
$old = "Sellora.CoreService"
$new = "Sellora.<NewName>"

Get-ChildItem -Recurse -File -Include *.cs,*.csproj,*.sln,*.http,*.json |
  Where-Object { $_.FullName -notmatch '\\(bin|obj)\\' } |
  ForEach-Object {
    (Get-Content $_.FullName -Raw) -replace [regex]::Escape($old), $new |
      Set-Content $_.FullName -NoNewline
  }
```

---

## 5. Rename service-specific class names and config

Some identifiers use the service name but not the full namespace. Rename these by
hand (or extend the script):

1. **DbContext class** — `CoreDbContext` → `<NewName>DbContext`
   - in `Infrastructure/Persistence/` (class name + filename)
   - and every reference: `Program.cs` (`AddDbContext<CoreDbContext>`),
     the test factory, and any test using it.
2. **Connection string** — in `src/Sellora.<NewName>.Api/appsettings.json`, change
   the SQLite database file name so services don't share a database file, e.g.
   `Data Source=sellora-core.db` → `Data Source=sellora-<newname>.db`.
3. **Audience / Jwt config** — review `appsettings.json` `Jwt` section; if the new
   service validates a different audience, update it.

---

## 6. Verify the clone builds and tests pass

```powershell
dotnet build
dotnet test
```

Both must succeed with the same results as the template. If the build fails:

- A missing rename in a `namespace`/`using` → compile error naming the old
  namespace. Fix that file, rebuild.
- A broken `<ProjectReference>` → the `.csproj` still points at an old path.
- `CoreDbContext` not found → a missed class-name reference from §5.

Fix the issue **and update this guide** so the next clone doesn't hit it.

---

## 7. Re-initialise as a new repository

```powershell
git init
git add -A
git commit -m "chore: scaffold Sellora.<NewName> service from template"
```

Then create the remote repo and push.

---

## 8. Optional: one-command clone script

Save as `new-service.ps1`. Run: `./new-service.ps1 -NewName Product -SourcePath ..\sellora-organization`

```powershell
param(
    [Parameter(Mandatory)] [string] $NewName,
    [Parameter(Mandatory)] [string] $SourcePath
)

$old = "Sellora.CoreService"
$new = "Sellora.$NewName"
$dest = "sellora-$($NewName.ToLower())"

# 1. Copy
Copy-Item -Recurse $SourcePath $dest
Push-Location $dest
Get-ChildItem -Recurse -Directory -Include bin,obj | Remove-Item -Recurse -Force
if (Test-Path .git) { Remove-Item -Recurse -Force .git }

# 2. Rename files/folders (deepest first so paths stay valid)
Get-ChildItem -Recurse | Where-Object { $_.Name -match [regex]::Escape($old) } |
  Sort-Object { $_.FullName.Length } -Descending |
  ForEach-Object {
    Rename-Item $_.FullName ($_.Name -replace [regex]::Escape($old), $new)
  }

# 3. Replace contents
Get-ChildItem -Recurse -File -Include *.cs,*.csproj,*.sln,*.http,*.json |
  ForEach-Object {
    (Get-Content $_.FullName -Raw) -replace [regex]::Escape($old), $new |
      Set-Content $_.FullName -NoNewline
  }

# 4. Rename the DbContext class (Core -> <NewName>)
Get-ChildItem -Recurse -File -Include *.cs |
  ForEach-Object {
    (Get-Content $_.FullName -Raw) -replace "CoreDbContext", "$($NewName)DbContext" |
      Set-Content $_.FullName -NoNewline
  }
Get-ChildItem -Recurse -File -Filter "CoreDbContext.cs" |
  ForEach-Object { Rename-Item $_.FullName "$($NewName)DbContext.cs" }

# 5. Unique connection string DB name
$appsettings = "src/$new.Api/appsettings.json"
if (Test-Path $appsettings) {
  (Get-Content $appsettings -Raw) -replace "sellora-core\.db", "sellora-$($NewName.ToLower()).db" |
    Set-Content $appsettings -NoNewline
}

Pop-Location
Write-Host "Created $dest. Run 'dotnet build' and 'dotnet test' to verify."
```

> After running the script, always run `dotnet build` and `dotnet test` to confirm
> the clone is complete. The script automates the mechanical renames; the build is
> the proof.

---
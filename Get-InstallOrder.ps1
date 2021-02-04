$ErrorActionPreference = "Stop"
$ExcludePackages = @("ezchakra", "ezmgr")

class NimblePackage {
  [string]$Name
  [string]$Folder
  [string[]]$Dependencies

  static [NimblePackage]FromFolder($folder) {
    Push-Location -Path $folder
    $Json = nimble.exe dump --json | ConvertFrom-Json
    Pop-Location
    $Result = [NimblePackage]::new()
    $Result.Name = $Json.name
    $Result.Folder = $folder
    $Result.Dependencies = $Json |
    Select-Object -ExpandProperty requires |
    Where-Object { $_.name -ne "nim" } |
    Select-Object -ExpandProperty name
    return $Result
  }

  [string]ToString() {
    if ($null -eq $this.Dependencies) {
      return ("({0})" -f $this.Name)
    }
    return ("({0}: {1})" -f $this.Name, ($this.Dependencies -join ", "))
  }

  [void]FilterOutDependencies($Names) {
    $this.Dependencies = $this.Dependencies | Where-Object { $Names -contains $_ }
  }
}

function Group-Packages($Source) {
  $Names = $Source | Select-Object -ExpandProperty Name
  foreach ($item in $Source) {
    $item.FilterOutDependencies($Names)
  }
  $Result = $Source | Group-Object {$_.Dependencies.Count -eq 0}
  $Result | Where-Object {$_.Name -eq $true } | Select-Object Group
  $Result | Where-Object {$_.Name -eq $false } | Select-Object Group
}

$script:Folder = Get-ChildItem .\packages -Directory
$script:Packages = $script:Folder |
ForEach-Object { [NimblePackage]::FromFolder($_) } |
Where-Object { $_.Name -notin $ExcludePackages }
while ($script:Packages.Count -gt 0) {
  $local:Parts = Group-Packages $script:Packages
  $script:Packages = $local:Parts[1] | Select-Object -ExpandProperty Group
  $local:Parts[0] | Select-Object -ExpandProperty Group | Select-Object -ExpandProperty Folder
}
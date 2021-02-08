function New-ExoCBAConnection {
    <#
    .SYNOPSIS
    Creates a connection to Exchange Online authenticated by certificate

    .DESCRIPTION
    Creates a connection to Exchange Online authenticated by certificate
    1. Creates Azure AD App
    2. Adds needed API Permissions to App
    3. Opens browser to grant admin consent
    4. Creates self-signed certificate
    5. Adds certificate to Current User' personal store
    6. Uploads certificate to Azure AD App
    7. Encrypts and saves AppID, thumbprint, and tenant domain
    8. Enables you to connect to Exchange Online with the certificate: Connect-Cloud -Tenant Contoso -EXOCBA

    .PARAMETER Tenant
    if tenant is contoso.onmicrosoft.com use contoso

    .PARAMETER Duration
    By default 1 year. Specify longer duration if desired.

    .EXAMPLE
    New-ExoCBAConnection -Tenant contoso

    .NOTES

    Once you run this function, you will be given the exact syntax to connect to Exchange Online with the certificate you created.

    You will be given two (2) different commands - Using either command is fine.

    You can now connect to Exchange Online with:

    --> Connect-Cloud -Tenant Contoso -EXOCBA

    You can also use this command:

    --> Connect-ExchangeOnline -AppId e527b732-95f9-abcd-aa66-1d8a07870898 -CertificateThumbprint 9427165D630XXXXXXXE7F5F85005D4A77BE0B -Organization contoso.onmicrosoft.com


    #>
    Param(

        [Parameter(Mandatory)]
        [string]
        $Tenant,

        [Parameter()]
        [int]
        $Duration = 1,

        [Parameter()]
        [switch]
        $GCCHigh
    )

    if ($Tenant -notlike "*.onmicrosoft.*") {
        if ($GCCHigh) {
            $Tenant = "$Tenant.onmicrosoft.us"
        }
        else {
            $Tenant = "$Tenant.onmicrosoft.com"
        }
    }

    $SelfSignedSplat = @{
        ExchangeCBA = $True
        Duration    = $Duration
        Tenant      = $Tenant
    }
    $CertInfo = New-PoshSelfSignedCert @SelfSignedSplat

    # Register Azure AD Application
    $RegisterAppSplat = @{
        Tenant                    = $Tenant
        App                       = 'EXO'
        ReturnAppObject           = $true
        AlsoCreateGraphConnection = $AlsoCreateGraphConnection
        GCCHIGH                   = $GCCHIGH
    }

    $AppObject = Register-GraphApplication @RegisterAppSplat

    do {
        $YorN = Read-Host "`r`n`r`nHas the Azure App been created and permissions granted consent by admin [Y/N] ?"
    } until ($YorN = 'Y')

    # Upload certificate to application by ApplicationId
    $cer = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $cer.Import($CertInfo.CerPath)
    $binCert = $cer.GetRawCertData()
    $Base64Value = [System.Convert]::ToBase64String($binCert)
    $bin = $cer.GetCertHash()
    $base64Thumbprint = [System.Convert]::ToBase64String($bin)

    $UploadSplat = @{
        ObjectId            = $AppObject.TenantObjectID
        CustomKeyIdentifier = $base64Thumbprint
        Type                = 'AsymmetricX509Cert'
        Usage               = 'Verify'
        Value               = $Base64Value
        StartDate           = $cer.NotBefore
        EndDate             = $cer.NotAfter
    }
    $null = New-AzureADApplicationKeyCredential @UploadSplat
    Write-Host "`r`n`r`n"
    Write-Host "Waiting for Application ID $($AppObject.TenantClientID)." -ForegroundColor Yellow
    Write-Host "If this takes longer than 2 minutes, paste the green link above into a brower to grant admin consent" -ForegroundColor Green
    do {
        Write-Host "Waiting for Application ID $($AppObject.TenantClientID)." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        $ServicePrincipal = Get-AzureADServicePrincipal -Filter "AppId eq '$($AppObject.TenantClientID)'"
    } until ($ServicePrincipal)

    if ($GCCHigh) {
        $role = Get-AzureADDirectoryRole -Filter "DisplayName eq 'Exchange Service Administrator'"
    }
    else {
        $role = Get-AzureADDirectoryRole -Filter "DisplayName eq 'Exchange Administrator'"
    }
    Add-AzureADDirectoryRoleMember -ObjectId $role.ObjectId -RefObjectId $ServicePrincipal.ObjectId

    $RootPath = $env:USERPROFILE + "\ps\"
    $KeyPath = $Rootpath + "creds\"

    if (-not (Test-Path $KeyPath)) {
        $null = New-Item -ItemType Directory -Path $KeyPath -ErrorAction STOP
    }
    $EXOCBAPath = (Join-Path $KeyPath "$($Tenant.split('.')[0]).EXOCBA.xml")
    if (Test-Path $EXOCBAPath) {
        $YorN = Read-Host "Connect-Cloud already has a connection. Overwrite [Y/N] ?"
        if ($YorN -eq 'N') {
            return
        }
    }

    $InitialDomain = ((Get-AzureADDomain).where{ $_.IsInitial }).Name
    @{
        AppId                 = $AppObject.TenantClientID
        CertificateThumbprint = $Cer.Thumbprint
        Organization          = $InitialDomain
    } | Export-Clixml $EXOCBAPath

    Write-Host "`r`n`r`nTo connect to Exchange Online with a certificate use:`r`n" -ForegroundColor Cyan
    Write-Host "Connect-Cloud " -ForegroundColor Yellow -NoNewline
    Write-Host "-Tenant " -ForegroundColor White -NoNewline
    Write-Host "$($Tenant.split('.')[0]) " -ForegroundColor Green -NoNewline
    if ($GCCHigh) {
        Write-Host "-EXOCBA " -ForegroundColor White -NoNewline
        Write-Host "-GCCHIGH"
    }
    else {
        Write-Host "-EXOCBA " -ForegroundColor White
    }

    Write-Host "`r`n`r`nor:`r`n" -ForegroundColor Cyan
    Write-Host "Connect-ExchangeOnline " -ForegroundColor Yellow -NoNewline
    Write-Host "-AppId " -ForegroundColor White -NoNewline
    Write-Host "$($AppObject.TenantClientID) " -ForegroundColor Green -NoNewline
    Write-Host "-CertificateThumbprint " -ForegroundColor White -NoNewline
    Write-Host "$($Cer.Thumbprint) " -ForegroundColor Green -NoNewline
    Write-Host "-Organization " -ForegroundColor White -NoNewline
    if ($GCCHigh) {
        Write-Host "$Tenant" -ForegroundColor Green -NoNewline
        Write-Host " -ExchangeEnvironmentName " -ForegroundColor White -NoNewline
        Write-Host "O365USGovGCCHigh `r`n`r`n`r`n`r`n" -ForegroundColor Green
    }
    else {
        Write-Host "$Tenant`r`n`r`n`r`n`r`n" -ForegroundColor Green
    }



}

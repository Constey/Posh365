﻿Function Get-MailboxMoveOnPremisesMailboxReport {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ReportPath
    )
    end {
        New-Item -ItemType Directory -Path $ReportPath -ErrorAction SilentlyContinue
        $BatchesFile = Join-Path $ReportPath 'Batches.csv'
        $Select = @(
            'BatchName', 'DisplayName', 'OrganizationalUnit', 'CompleteBatchOn'
            'CompleteBatchonTimePT', 'MailboxGB', 'ArchiveGB', 'DeletedGB', 'TotalGB'
            'LastLogonTime', 'ItemCount', 'UserPrincipalName', 'PrimarySmtpAddress'
            'AddressBookPolicy', 'RetentionPolicy', 'AccountDisabled', 'Alias'
            'Database', 'OU', 'Office', 'RecipientTypeDetails', 'UMEnabled'
            'ForwardingAddress', 'ForwardingRecipientType', 'DeliverToMailboxAndForward'
        )
        Get-MailboxMoveOnPremisesReportHelper | Select-Object $Select | Export-Csv $BatchesFile -NoTypeInformation -Encoding UTF8

        $ExcelSplat = @{
            Path                    = (Join-Path $ReportPath 'Batches.xlsx')
            TableStyle              = 'Medium16'
            FreezeTopRowFirstColumn = $true
            NoLegend                = $true
            AutoSize                = $true
            BoldTopRow              = $true
            AutoNameRange           = $true
            ClearSheet              = $true
            WorksheetName           = 'Batches'
            ErrorAction             = 'SilentlyContinue'
        }
        $BatchesFile | Where-Object { $_ } | ForEach-Object { Import-Csv $_ | Export-Excel @ExcelSplat }
    }
}
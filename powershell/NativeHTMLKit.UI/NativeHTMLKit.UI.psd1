@{
    RootModule = 'NativeHTMLKit.UI.psm1'
    ModuleVersion = '0.1.0'
    GUID = '5960cbe6-d2d1-47f6-b38d-664a743ff437'
    Author = 'NativeHTMLKit contributors'
    CompanyName = 'NativeHTMLKit'
    Copyright = '(c) NativeHTMLKit contributors'
    Description = 'Minimal responsive and reactive UI toolkit over the public NativeHTMLKit PowerShell SDK.'
    PowerShellVersion = '5.1'
    RequiredModules = @(@{ModuleName='NativeHTMLKit';ModuleVersion='0.1.0'})
    FunctionsToExport = @(
        'New-NHKUi','New-NHKUiState','New-NHKUiComputed','Start-NHKUi','Stop-NHKUi','Sync-NHKUi','Get-NHKUiHtml','Get-NHKUiDiagnostics',
        'Add-NHKUiColumn','Add-NHKUiRow','Add-NHKUiGrid','Add-NHKUiCard',
        'Add-NHKUiHeading','Add-NHKUiText','Add-NHKUiBadge','Add-NHKUiAlert',
        'Add-NHKUiButton','Add-NHKUiInput','Add-NHKUiCheckbox','Add-NHKUiSelect',
        'Add-NHKUiWhen','Add-NHKUiTextList','Add-NHKUiHtml'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{PSData=@{Tags=@('NativeHTMLKit','UI','Desktop','Reactive');LicenseUri='https://opensource.org/licenses/MIT'}}
}

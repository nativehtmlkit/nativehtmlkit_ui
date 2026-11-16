@{
    RootModule = 'NativeHTMLKit.UI.psm1'
    ModuleVersion = '0.1.1'
    GUID = '5960cbe6-d2d1-47f6-b38d-664a743ff437'
    Author = 'NativeHTMLKit contributors'
    CompanyName = 'NativeHTMLKit'
    Copyright = '(c) NativeHTMLKit contributors'
    Description = 'Compact reactive PowerShell desktop UI over the public NativeHTMLKit SDK. Buttons, inputs, layouts, state and list components. Quick start and gallery: https://github.com/nativehtmlkit/nativehtmlkit . API: https://github.com/nativehtmlkit/nativehtmlkit_ui .'
    PowerShellVersion = '5.1'
    RequiredModules = @(@{ModuleName='NativeHTMLKit';ModuleVersion='0.1.0'})
    FunctionsToExport = @(
        'New-NHKUi','New-NHKUiState','New-NHKUiComputed','Start-NHKUi','Stop-NHKUi','Sync-NHKUi','Get-NHKUiHtml','Get-NHKUiDiagnostics','Invoke-NHKUiBatch',
        'Add-NHKUiColumn','Add-NHKUiRow','Add-NHKUiGrid','Add-NHKUiCard',
        'Add-NHKUiHeading','Add-NHKUiText','Add-NHKUiBadge','Add-NHKUiAlert',
        'Add-NHKUiButton','Add-NHKUiInput','Add-NHKUiCheckbox','Add-NHKUiSelect',
        'Add-NHKUiWhen','Add-NHKUiTextList','Add-NHKUiHtml'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{PSData=@{Tags=@('NativeHTMLKit','UI','Desktop','Reactive');LicenseUri='https://opensource.org/licenses/MIT';ProjectUri='https://github.com/nativehtmlkit/nativehtmlkit_ui';ReleaseNotes='0.1.1: documentation and onboarding update; no new component API claims.'}}
}

param (    
    [ValidateScript({Test-Path $_})]
    [string]
    $WSBFile =  $PSScriptRoot + "\Sandbox.wsb",

    [ValidateScript({Test-Path $_})]
    [string]
    $HostFolder = (Get-Item $PSScriptRoot).Parent.FullName,
    
    [string]
    $SandboxFolder = $(Join-Path -Path "C:\Users\WDAGUtilityAccount\" -ChildPath (Get-Item $PSScriptRoot).Parent.Name),

    [bool]$ReadOnly = $true,
    [bool]$vGPU = $true,
    [bool]$Networking = $true,
    [bool]$ProtectedClient = $false,
    [bool]$AudioInput = $false,
    [bool]$VideoInput = $false,
    [bool]$PrinterRedirection = $false,
    [bool]$ClipboardRedirection = $true
)
Process
{
    [xml]$WSBXML = Get-Content $WSBFile

    $RunFile = Join-Path -Path $PSScriptRoot -ChildPath "Run.cmd"
    if((Test-Path $RunFile) -and ($null -ne (Get-Content $RunFile))) {
        $RunCommand = Join-Path -Path $SandboxFolder -ChildPath $(Get-Item $PSScriptRoot).Name -AdditionalChildPath "Run.cmd"
        $WSBXML.Configuration.LogonCommand.Command = $RunCommand
    } else {
        $WSBXML.Configuration.LogonCommand.Command = "explorer.exe $SandboxFolder"
    }

    $WSBXML.Configuration.MappedFolders.MappedFolder.HostFolder = $HostFolder
    $WSBXML.Configuration.MappedFolders.MappedFolder.SandboxFolder = $SandboxFolder
    $WSBXML.Configuration.MappedFolders.MappedFolder.ReadOnly = $ReadOnly

    $WSBXML.Configuration.vGPU = if ($vGPU) {"Enable"} else {"Disable"}
    $WSBXML.Configuration.Networking = if ($Networking) {"Default"} else {"Disable"}
    $WSBXML.Configuration.ProtectedClient = if ($ProtectedClient) {"Enable"} else {"Disable"}
    $WSBXML.Configuration.AudioInput = if ($AudioInput) {"Enable"} else {"Disable"}
    $WSBXML.Configuration.VideoInput = if ($VideoInput) {"Enable"} else {"Disable"}

    $WSBXML.Configuration.PrinterRedirection = if ($PrinterRedirection) {"Enable"} else {"Disable"}
    $WSBXML.Configuration.ClipboardRedirection= if ($ClipboardRedirection) {"Default"} else {"Disable"}

    $WSBXML.Save($WSBFile)

    WindowsSandbox.exe $PSScriptRoot\Sandbox.wsb
}
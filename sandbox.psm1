<#PSScriptInfo
.VERSION 2.0
.AUTHOR luke@lukedavidson.org
.COPYRIGHT 2023 Luke Davidson. All rights reserved.
.LICENSEURI https://github.com/lukecdavidson/sandbox/blob/master/LICENSE
.PROJECTURI https://github.com/lukecdavidson/sandbox
#>
function Approve-VolumesMap {
    param([hashtable[]]$Volumes)

    foreach ($Volume in $Volumes) {
        if ($Volume.Keys -notcontains "Host") {
            throw 'Host folder definition missing from volume mapping dictionary.'
        }
        if ($Volume.Keys -notcontains "Container") {
            throw 'Container folder definition missing from volume mapping dictionary.'
        }
        if (-not (Test-Path -PathType Container -Path $($Volume['Host']))) {
            throw "Path $($Volume['Host']) does not exist. Please specify an existing host folder to map."
        }
        if (-not ($($Volume['container']).ForEach({$_.ToUpper().startswith('C:\')}))) {
            throw "Path $($Volume['container']) is invalid. Please specify a path on C:\ for the container folder."
        }
    }
    return $true
}

function Start-Sandbox {
    <#
    .SYNOPSIS
    Starts Windows Sandbox
    .DESCRIPTION
    PowerShell wrapper that builds the configuration XML for Windows Sandbox and executes.
    .EXAMPLE
    Start-Sandbox -Volume @{'Host'=$pwd; 'Container'='C:\Data'; 'Write'=$true}, @{'Host'='D:\mycode'; 'Container'='C:\mycode'} -Networking $false
    #>
    
    [CmdletBinding(DefaultParameterSetName='x')]
    Param (
        [ValidateScript({$_.ToLower().EndsWith(".wsb")})]
        [string]
        $Path = "$env:Temp\Sandbox.wsb",

        [ValidateScript({Approve-VolumesMap -Volumes $_})]
        [hashtable[]]
        $Volumes,
    
        [parameter(ParameterSetName="RunCommand")]
        [string]
        $RunCommand,
    
        [parameter(ParameterSetName="RunScript")]
        [string]
        $RunPSScript,
    
        [bool]$vGPU,
        [bool]$Networking,
        [bool]$ProtectedClient,
        [bool]$AudioInput,
        [bool]$VideoInput,
        [bool]$PrinterRedirection,
        [bool]$ClipboardRedirection
    )
    Process
    {
        $xml = [xml]::new()
        $xml.AppendChild($xml.CreateElement("Configuration")) | Out-Null
        if ($null -ne $Volumes) {
    		    $xml.SelectSingleNode("Configuration").AppendChild($xml.CreateElement("MappedFolders")) | Out-Null
    		    foreach ($Volume in $Volumes) {	
    			      $xml.SelectSingleNode("//MappedFolders").AppendChild($xml.CreateElement("MappedFolder")) | Out-Null
    			      $MappedFolder = $xml.SelectNodes("//MappedFolder")[$Volumes.IndexOf($Volume)]
    			      foreach ($Child in "HostFolder", "SandboxFolder", "ReadOnly") {
    				        $MappedFolder.AppendChild($xml.CreateElement($Child)) | Out-Null
    			      }
    
    			      $MappedFolder.HostFolder = $Volume['Host']
    			      $MappedFolder.SandboxFolder = $Volume['Container']
    			      $MappedFolder.ReadOnly = if ($null -eq $Volume['Write']) {"True"} elseif ($Volume['Write'] -eq $true) {"False"}
        	  }
        }
        if ($RunCommand -ne ""){
    		$xml.SelectSingleNode("Configuration").AppendChild($xml.CreateElement("LogonCommand")) | Out-Null
    		$xml.SelectSingleNode("//LogonCommand").AppendChild($xml.CreateElement("Command")) | Out-Null
    		$xml.Configuration.LogonCommand.Command = $RunCommand
        }
        if ($RunPSScript -ne "") {
	    	$xml.SelectSingleNode("Configuration").AppendChild($xml.CreateElement("LogonCommand")) | Out-Null
    		$xml.SelectSingleNode("//LogonCommand").AppendChild($xml.CreateElement("Command")) | Out-Null
    		$EscapedScript = $RunPSScript.Replace(" ","`` ")
        	$xml.Configuration.LogonCommand.Command = "powershell.exe -ExecutionPolicy Bypass $EscapedScript"
        }
        if ($vGPU -ne "") {
    		$xml.SelectSingleNode("Configuration").AppendChild($xml.CreateElement("vGPU")) | Out-Null
    		$xml.Configuration.vGPU = if ($vGPU) {"Enable"} else {"Disable"}
        }
        if ($Networking -ne "") {
    		$xml.SelectSingleNode("Configuration").AppendChild($xml.CreateElement("MappedFolders")) | Out-Null
    		$xml.Configuration.Networking = if ($Networking) {"Default"} else {"Disable"}
        }
        if ($ProtectedClient -ne "") {
    		$xml.SelectSingleNode("Configuration").AppendChild($xml.CreateElement("MappedFolders")) | Out-Null
    		$xml.Configuration.ProtectedClient = if ($ProtectedClient) {"Enable"} else {"Disable"}
        }
        if ($AudioInput -ne "") {
    		$xml.SelectSingleNode("Configuration").AppendChild($xml.CreateElement("MappedFolders")) | Out-Null
    		$xml.Configuration.AudioInput = if ($AudioInput) {"Enable"} else {"Disable"}
        }
        if ($VideoInput -ne "") {
    		$xml.SelectSingleNode("Configuration").AppendChild($xml.CreateElement("MappedFolders")) | Out-Null
    		$xml.Configuration.VideoInput = if ($VideoInput) {"Enable"} else {"Disable"}
        }
        if ($PrinterRedirection -ne "") {
    		$xml.SelectSingleNode("Configuration").AppendChild($xml.CreateElement("MappedFolders")) | Out-Null
	    	$xml.Configuration.PrinterRedirection = if ($PrinterRedirection) {"Enable"} else {"Disable"}
        }
        if ($ClipboardRedirection -ne "") {
            $xml.SelectSingleNode("Configuration").AppendChild($xml.CreateElement("MappedFolders")) | Out-Null
            $xml.Configuration.ClipboardRedirection= if ($ClipboardRedirection) {"Default"} else {"Disable"}
        }
    
        $xml.Save($Path)
        WindowsSandbox.exe $Path
    }
}

New-Alias -Name sandbox -Value Start-Sandbox
Export-ModuleMember -Function Start-Sandbox -Alias sandbox
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
        # Specifies a path to an input WSB file which is run by WindowsSandbox.exe
        [Parameter(Mandatory=$false, Position=0, ParameterSetName="InputWsb", HelpMessage="Path to WSB file.")]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        # Path to the Sandbox file to write to. Useful to track how you last ran Windows Sandbox or to run directly with the WindowsSandbox.exe.
        [Parameter(Mandatory=$false, ParameterSetName="BuiltWsb", HelpMessage="Output file for the built WSB XML.")]
        [ValidateScript({$_.ToLower().EndsWith(".wsb")})]
        [string]
        $OutFile = "$env:Temp\Sandbox.wsb",

        # Hashtable mapping host paths to container paths
        [Parameter(Mandatory=$false, ParameterSetName="BuiltWsb")]
        [ValidateScript({Approve-VolumesMap -Volumes $_})]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Volumes,
    
        # Path to a powershell script to run inside of the container
        [Parameter(Mandatory=$false, ParameterSetName="BuiltWsb")]
        [string]
        $PSScript,
    
        # Sandbox features to enable or disable
        [Parameter(Mandatory=$false, ParameterSetName="BuiltWsb")]
        [hashtable]
        $FeatureSet
    )

    Process
    {
        $xml = [xml]::new()
        $xml.AppendChild($xml.CreateElement("Configuration")) | Out-Null
        if ($Volumes) {
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

        if ($PSScript -ne "") {
	    	$xml.SelectSingleNode("Configuration").AppendChild($xml.CreateElement("LogonCommand")) | Out-Null
    		$xml.SelectSingleNode("//LogonCommand").AppendChild($xml.CreateElement("Command")) | Out-Null
    		$EscapedScript = $RunPSScript.Replace(" ","`` ")
        	$xml.Configuration.LogonCommand.Command = "powershell.exe -ExecutionPolicy Bypass $EscapedScript"
        }

        foreach ($i in $FeatureSet.GetEnumerator()) {
            $xml.SelectSingleNode("Configuration").AppendChild($xml.CreateElement($i.Name))
            $xml.Configuration.$i.Name = if (($i.Name -eq "Networking" -and $i.Value -eq $true)) {"Default"} else {"$($i.Value)"}
        }
    
        $xml.Save($OutFile)
        WindowsSandbox.exe $OutFile
    }
}


New-Alias -Name sandbox -Value Start-Sandbox
Export-ModuleMember -Function Start-Sandbox -Alias sandbox

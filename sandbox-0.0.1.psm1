function sandbox {
    [CmdletBinding(DefaultParameterSetName='x')]
    Param (
        [ValidateScript({
    	foreach ($v in $_) {
    		$vArgs = $v.split(";")
    		if ((Test-Path $vArgs[0]) -eq $False) {
    			throw [System.IO.DirectoryNotFoundException]::new("Host path $($vArgs[0]) not found. Please specify a valid host folder for the volume mapping.")
    		}
    		if (($vArgs[1].StartsWith("C:\")) -eq $False) {
    			throw [System.IO.DirectoryNotFoundException]::new("Sandbox path $($vArgs[1]) is invalid. Please specify a full path for the sandbox folder.")
    		}
    		if ($vArgs.Length -eq 3) {
    			if ($vArgs[2] -notin "RW", "RO") {throw "Volume mode $($vArgs[2]) is invalid. Specify 'RW' or 'RO' for the volume mode."}
       		}
    		return $True
    	}
        })]
        [array]$Volume,
    
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
        if ($null -ne $Volume) {
    		$xml.SelectSingleNode("Configuration").AppendChild($xml.CreateElement("MappedFolders")) | Out-Null
    		foreach ($i in $Volume) {
            	$VolumeArgs = $i.split(";")
    			$xml.SelectSingleNode("//MappedFolders").AppendChild($xml.CreateElement("MappedFolder")) | Out-Null
    			$MappedFolder = $xml.SelectNodes("//MappedFolder")[$Volume.IndexOf($i)]
    			foreach ($Child in "HostFolder", "SandboxFolder", "ReadOnly") {
    				$MappedFolder.AppendChild($xml.CreateElement($Child)) | Out-Null
    			}
    
    			$MappedFolder.HostFolder = $VolumeArgs[0]
    			$MappedFolder.SandboxFolder = $VolumeArgs[1]
    			$MappedFolder.ReadOnly = if ($VolumeArgs.Length -eq 2) {"True"} elseif ($VolumeArgs[2] -eq "RW") {"False"}
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
    
        $xml.Save("$PSScriptRoot\Sandbox.wsb")
        WindowsSandbox.exe "$PSScriptRoot\Sandbox.wsb"
    }
}
﻿add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

<# 
 .Synopsis
	Creates a Base64 hash for further requests against your StoreOnce system(s).

 .Description
	Creates a Base64 hash for further requests against your StoreOnce system(s). 
	This should be the first Commandlet you use from this module.
  
 .Example
   Set-SOCredentials

#>
function Set-SOCredentials {
	
	[String]$SOUser = (Read-Host 'D2D username?')
	$SOPassword = (Read-Host 'D2D password?' -AsSecureString)
	[String]$SOPasswordClear =  [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SOPassword))
  	$global:SOCred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($SOUser):$($SOPasswordClear)"))
	if ($SOCred -eq $null) {Write-Error "No Credential Set"; return}
	
	} # end function

<# 
 .Synopsis
	Lists all ServiceSets from your your StoreOnce system(s).

 .Description
	Lists all ServiceSets from your your StoreOnce system(s).
	Outputs: ArrayIP,SSID,Name,Alias,OverallHealth,SerialNumber,Capacity(GB).Free(GB),UserData(GB),DiskData(GB)
	
 .Parameter D2DIPs
  IP Address of your StoreOnce system(s).

 .Example
   Get-SOSIDs -D2DIPs 192.168.2.1, 192.168.2.2

#>
function Get-SOSIDs {
	param (
	[parameter(Mandatory=$true)]
	$D2DIPs
	)
	
	if ($SOCred -eq $null) {Write-Error "No Credential Set! Use 'set-SOCredentials'"; return}
	$SOSIDs =  New-Object System.Collections.ArrayList
	
	foreach ($D2DIP in $D2DIPs) {
		$SIDCall = @{uri = "https://$D2DIP/storeonceservices/cluster/servicesets/";
					Method = 'GET'; #(or POST, or whatever)
						Headers = @{Authorization = 'Basic ' + $SOCred;
									Accept = 'text/xml'
				} 
			} 
		
		$SIDsResponse = Invoke-RestMethod @SIDCall
		$SIDCount = ($SIDsResponse.document.servicesets.serviceset).count
		if ($SIDCount -eq $null) {$SIDCount = 1}
		[Array] $SSID = $SIDsResponse.document.servicesets.serviceset.properties.ssid
		[Array] $Name = $SIDsResponse.document.servicesets.serviceset.properties.name
		[Array] $Alias = $SIDsResponse.document.servicesets.serviceset.properties.alias
		[Array] $OverallHealth = $SIDsResponse.document.servicesets.serviceset.properties.overallHealth
		[Array] $SerialNumber = $SIDsResponse.document.servicesets.serviceset.properties.serialNumber
		[Array] $CapacityBytes = $SIDsResponse.document.servicesets.serviceset.properties.capacityBytes
		[Array] $FreeBytes = $SIDsResponse.document.servicesets.serviceset.properties.freeBytes
		[Array] $UserBytes = $SIDsResponse.document.servicesets.serviceset.properties.userBytes
		[Array] $DiskBytes = $SIDsResponse.document.servicesets.serviceset.properties.diskBytes
		
		for ($i = 0; $i -lt $SIDCount; $i++ ){
				
			$row = New-object PSObject
			$row  | Add-Member -Name ArrayIP -Value $D2DIP -Membertype NoteProperty
			$row  | Add-Member -Name SSID -Value $SSID[$i]-Membertype NoteProperty
			$row  | Add-Member -Name Name -Value $Name[$i] -Membertype NoteProperty
			$row  | Add-Member -Name Alias -Value $Alias[$i] -Membertype NoteProperty
			$row  | Add-Member -Name OverallHealth -Value $OverallHealth[$i] -Membertype NoteProperty
			$row  | Add-Member -Name SerialNumber -Value $SerialNumber[$i] -Membertype NoteProperty
			$row  | Add-Member -Name "Capacity(GB)" -Value ([math]::Round(($CapacityBytes[$i] / 1073741824),2))  -Membertype NoteProperty
			$row  | Add-Member -Name "Free(GB)" -Value ([math]::Round(($FreeBytes[$i] / 1073741824),2))  -Membertype NoteProperty
			$row  | Add-Member -Name "UserData(GB)" -Value ([math]::Round(($UserBytes[$i] / 1073741824),2))  -Membertype NoteProperty
			$row  | Add-Member -Name "DiskData(GB)" -Value ([math]::Round(($DiskBytes[$i] / 1073741824),2))  -Membertype NoteProperty
			$SOSIDs += $row
			
			} 
		}
	
	Return $SOSIDs
	
	} # end function

<# 
 .Synopsis
	Lists all Catalyst Stores from your your StoreOnce system(s).

 .Description
	Lists all Catalyst Stores from your your StoreOnce system(s).
	Outputs: ArrayIP,SSID,Name,SizeOnDisk(GB),UserDataStored(GB),DedupeRatio
	
 .Parameter D2DIPs
  IP Address of your StoreOnce system(s).

 .Example
   Get-SOCatStores -D2DIPs 192.168.2.1, 192.168.2.2

#>
function Get-SOCatStores {
	param (
	[parameter(Mandatory=$true)]
	$D2DIPs
	)
	
	if ($SOCred -eq $null) {Write-Error "No System Credential Set! Use 'Set-SOCredentials'."; return}
	$SOCatStores =  New-Object System.Collections.ArrayList
	
	foreach ($D2DIP in $D2DIPs) {
		$SIDCall = @{uri = "https://$D2DIP/storeonceservices/cluster/servicesets/";
					Method = 'GET'; #(or POST, or whatever)
						Headers = @{Authorization = 'Basic ' + $SOCred;
									Accept = 'text/xml'
				} 
			} 
		
		$SIDsResponse = Invoke-RestMethod @SIDCall
		$SIDCount = ($SIDsResponse.document.servicesets.serviceset).count
		if ($SIDCount -eq $null) {$SIDCount = 1}
		
		for ($x = 1; $x -le $SIDCount; $x++ ){
			$StoreInf = @{uri = "https://$D2DIP/storeonceservices/cluster/servicesets/$x/services/cat/stores/";
						Method = 'GET'; #(or POST, or whatever)
							Headers = @{Authorization = 'Basic ' + $SOCred;
										Accept = 'text/xml'
					} 
				} 
			$StoreInfResponse = Invoke-RestMethod @StoreInf
		
			[Array] $Name = $StoreInfResponse.document.stores.store.properties.name
			[Array] $SSID = $StoreInfResponse.document.stores.store.properties.ssid
			[Array] $UserDataStored = $StoreInfResponse.document.stores.store.properties.userdatastored
			[Array] $SizeOnDisk = $StoreInfResponse.document.stores.store.properties.sizeondisk
			[Array] $DDRate = $StoreInfResponse.document.stores.store.properties.deduperatio
			$StoresCount = ($Name).count
		
			$DDRate = $DDRate | foreach {$i=1} {if ($i++ %2){$_}}
		
			for ($i = 0; $i -lt $StoresCount; $i++ ){
						
				$row = New-object PSObject
				$row  | Add-Member -Name ArrayIP -Value $D2DIP -Membertype NoteProperty
				$row  | Add-Member -Name SSID -Value $SSID[$i] -Membertype NoteProperty
				$row  | Add-Member -Name Name -Value $Name[$i] -Membertype NoteProperty
				$row  | Add-Member -Name "SizeOnDisk(GB)" -Value ([math]::Round(($SizeOnDisk[$i]),2)) -Membertype NoteProperty
				$row  | Add-Member -Name "UserDataStored(GB)" -Value ([math]::Round(($UserDataStored[$i]),2)) -Membertype NoteProperty
				$row  | Add-Member -Name DedupeRatio -Value $DDRate[$i] -Membertype NoteProperty
				$SOCatStores += $row
			
		
				}
			}
	
		} 
		
	Return $SOCatStores
	
	}# end function

<# 
 .Synopsis
	Lists all NAS Stores from your your StoreOnce system(s).

 .Description
	Lists all NAS Stores from your your StoreOnce system(s).
	Outputs: ArrayIP,SSID,Name,AccessProtocol,SizeOnDisk(GB),UserDataStored(GB),DedupeRatio
	
 .Parameter D2DIPs
  IP Address of your StoreOnce system(s).

 .Example
   Get-SONasShares -D2DIPs 192.168.2.1, 192.168.2.2

#>
function Get-SONasShares {
	param (
	[parameter(Mandatory=$true)]
	$D2DIPs
	)
	
	if ($SOCred -eq $null) {Write-Error "No System Credential Set! Use 'Set-SOCredentials'."; return}
	$SONasShares =  New-Object System.Collections.ArrayList
	
	foreach ($D2DIP in $D2DIPs) {
		$SIDCall = @{uri = "https://$D2DIP/storeonceservices/cluster/servicesets/";
					Method = 'GET'; #(or POST, or whatever)
						Headers = @{Authorization = 'Basic ' + $SOCred;
									Accept = 'text/xml'
				} 
			} 
		
		$SIDsResponse = Invoke-RestMethod @SIDCall
		$SIDCount = ($SIDsResponse.document.servicesets.serviceset).count
		if ($SIDCount -eq $null) {$SIDCount = 1}
		
		for ($x = 1; $x -le $SIDCount; $x++ ){
			$ShareInf = @{uri = "https://$D2DIP/storeonceservices/cluster/servicesets/$x/services/nas/shares/";
						Method = 'GET'; #(or POST, or whatever)
							Headers = @{Authorization = 'Basic ' + $SOCred;
										Accept = 'text/xml'
					} 
				} 
			$ShareInfResponse = Invoke-RestMethod @ShareInf
		
			[Array] $Name = $ShareInfResponse.document.shares.share.properties.name
			[Array] $AccessProtocol = $ShareInfResponse.document.shares.share.properties.accessProtocol
			[Array] $SSID = $ShareInfResponse.document.shares.share.properties.ssid
			[Array] $UserDataStored = $ShareInfResponse.document.shares.share.properties.userdatastored
			[Array] $SizeOnDisk = $ShareInfResponse.document.shares.share.properties.sizeondisk
			[Array] $DDRate = $ShareInfResponse.document.shares.share.properties.deduperatio
			$ShareCount = ($Name).count
		
			for ($i = 0; $i -lt $ShareCount; $i++ ){
						
				$row = New-object PSObject
				$row  | Add-Member -Name ArrayIP -Value $D2DIP -Membertype NoteProperty
				$row  | Add-Member -Name SSID -Value $SSID[$i] -Membertype NoteProperty
				$row  | Add-Member -Name Name -Value $Name[$i] -Membertype NoteProperty
				$row  | Add-Member -Name AccessProtocol -Value $AccessProtocol[$i] -Membertype NoteProperty
				$row  | Add-Member -Name "SizeOnDisk(GB)" -Value ([math]::Round(($SizeOnDisk[$i]),2)) -Membertype NoteProperty
				$row  | Add-Member -Name "UserDataStored(GB)" -Value ([math]::Round(($UserDataStored[$i]),2)) -Membertype NoteProperty
				$row  | Add-Member -Name DedupeRatio -Value $DDRate[$i] -Membertype NoteProperty
				$SONasShares += $row
			
		
				}
			}
	
		} 
		
	Return $SONasShares
	
	}# end function

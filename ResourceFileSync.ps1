#requires -version 2.0

$currentDir = Split-Path -parent $MyInvocation.MyCommand.Definition
. ($currentDir + "\Common.ps1"); 

function syncResourceFiles($sourceDir, $destDir) {
	$files = [System.IO.Directory]::GetFiles($sourceDir, "*.resx", [System.IO.SearchOption]::AllDirectories);
	
	if($sourceDir.EndsWith("\") -eq $false) {
		$sourceDir = $sourceDir + "\";
	}
	
	foreach($file in $files) {
		$relPath = $file.Substring($sourceDir.Length);
		
		$destPath = [System.IO.Path]::Combine($destDir, $relPath);
		
		if([System.IO.File]::Exists($destPath) -eq $true) {
			ensureFileWritable ($destPath);
		}
		
		[System.IO.File]::Copy($file, $destPath, $true);
	}	
}

$sourceDir = "D:\Projects\TravcomCRM\trunk\Travcom.Global\Rahul";
$destDir = "F:\(4) Projects\(5) .NET\(3) Web\(4) TravCom\dev\Rahul";

syncResourceFiles ($sourceDir) ($destDir);

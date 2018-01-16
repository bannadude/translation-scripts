#requires -version 2.0

$currentDir = Split-Path -parent $MyInvocation.MyCommand.Definition
#Take care to leave the ending slash at the end of $appDir here.
$appDir = 'F:\HMIS_Spanish\'

. ($currentDir + "\Common.ps1"); 
. ($currentDir + "\ResourceFileGenerator.ps1"); 
. ($currentDir + "\AddMetaTag.ps1"); 
. ($currentDir + "\MetaTagExtractor.ps1"); 
. ($currentDir + "\JsStringExtractor.ps1"); 
. ($currentDir + "\GTranslate.ps1"); 

function processDirectory($dirPath, $searchOption) {
	$files = [System.IO.Directory]::GetFiles($dirPath, "*.ascx", $searchOption);
	ensureLocaleResourceFiles($files);
	addMetaTagsInFiles($files);
	extractMetaTagsToPrimaryResources($files);
	
	$files = [System.IO.Directory]::GetFiles($dirPath, "*.aspx", $searchOption);
	ensureLocaleResourceFiles($files);
	addMetaTagsInFiles($files);
	extractMetaTagsToPrimaryResources($files);
	
	$files = [System.IO.Directory]::GetFiles($dirPath, "*.js", $searchOption);
	extractTranslatableStringsToPrimaryResources($files);
	
	if ($searchOption -eq [System.IO.SearchOption]::TopDirectoryOnly) {
		$files = [System.IO.Directory]::GetFiles(($dirPath + '\App_LocalResources'), "*.resx", [System.IO.SearchOption]::TopDirectoryOnly);
	} else {
		$files = [System.IO.Directory]::GetFiles($dirPath, "*.resx", [System.IO.SearchOption]::AllDirectories);
	}
	updateAndTranslateSecondaryResourceFiles ($files) ($false);
}

clear

#Root App directory.
processDirectory ($appDir) ([System.IO.SearchOption]::AllDirectories);

#Specific folder files.
#Take care to leave the ending slash at the end the path below.
#processDirectory ($appDir + "MyFolder\") ([System.IO.SearchOption]::AllDirectories);

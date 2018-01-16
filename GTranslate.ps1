#requires -version 2.0

$gturl = "https://www.googleapis.com/language/translate/v2?key=AIzaSyAysIhzPJNbOG1rSKVq1YjF93x2f_MIDnU&source=en";

[System.Reflection.Assembly]::LoadWithPartialName("System.Xml.Linq") | Out-Null;


function addElementToTranslate($primaryElements, $current, $curTranslatingList, $isJsResourceFile, $retranslate, [ref] $url) {
	$resName = $current.Attribute("name").Value;
	$resValue = $current.Element("value").Value;
	$comment = $current.Element("comment");
	if($comment -ne $null) {$comment = $comment.Value;}
	
	$continueTranslation = $true;
	if($comment -eq "NT") {
		#NT comment means no translation.
		$continueTranslation = $false;
	} elseif($comment -eq "Manual") {
		#Manual comment means manual translation, not to overridden automatically.
		$continueTranslation = $false;
	} elseif($comment -eq "Translated") {
		if($retranslate -ne $true) {
			$continueTranslation = $false;
		}
	}
	
	if($continueTranslation -eq $true) {
		if($isJsResourceFile) {
			#Javascript resource
			$url.Value += "&q=" + [System.Web.HttpUtility]::UrlEncode($resName);
			$curTranslatingList.Add($current);
			return ($true);
			
		} else {
			#Regular ASP.NET resource
			$primaryElement = $null;
			$primaryElements | ForEach { if($_.Attribute("name").Value -eq $resName) {$primaryElement = $_;}}
			if($primaryElement -ne $null ){$resValue = $primaryElement.Element("value").Value;}
				else {$resValue = $null;}
			if($resValue -ne $null ) {
				$url.Value += "&q=" + [System.Web.HttpUtility]::UrlEncode($resValue);
				$curTranslatingList.Add($current);
				return ($true);
			} else {
				return ($false);
			}
		}
	} else {
		return ($false);
	}
}

function updateAndTranslateSecondaryResourceFiles ($files, $retranslate) {
	"Updating Localized Resource files..."

	foreach ($primaryFile in $files)
	{
		$resourceDir=[System.IO.Path]::GetDirectoryName($primaryFile);
		$resourceFileName=[System.IO.Path]::GetFileNameWithoutExtension($primaryFile);

		$primaryResources=$null;
		$primaryElements=$null;
		foreach ($dependentFile in [System.IO.Directory]::GetFiles($resourceDir, $resourceFileName + ".*.resx", [System.IO.SearchOption]::TopDirectoryOnly))
		{
			#if (([System.IO.File]::GetLastWriteTime($primaryFile)) -gt ([System.IO.File]::GetLastWriteTime($dependentFile)))
			#{
				#Load Primary resources
				if ($primaryResources -eq $null)
				{
					$primaryResources = [System.Xml.Linq.XDocument]::Load($primaryFile);
					$primaryElements = $primaryResources.Root.Elements("data");
				}
				
				"Updating resource file: " + $dependentFile;
				#Load Dependent resources
				$dependentResources=[System.Xml.Linq.XDocument]::Load($dependentFile);
				$dependentElements=$dependentResources.Root.Elements("data");
				
				#Update missing primary resources to dependent resources (these were probably added to primary resources at a later time).
				foreach ($primaryElement in $primaryElements)
				{
					$resName=$primaryElement.Attribute("name").Value;
					$hasExisting=$false;
					foreach ($dataElement in $dependentElements) { 
						if($dataElement.Attribute("name").Value -eq $resName) {
							$hasExisting = $true;
						}
					};
					if ($hasExisting -eq $false)
					{
						$clonedElement=New-Object System.Xml.Linq.XElement ($primaryElement);
						$dependentResources.Root.Add($clonedElement);
					}
				}
				
				#Save the dependent resources.
				#Ensure dependent-file read-only attribute is not set (this can be set by things like Version Control Systems).
				ensureFileWritable ($dependentFile);
				$dependentResources.Save($dependentFile);
				
				#Update Translation for this file from Google Translate.
				#Only pick first 2 characters for the language from the dependent file name (that's what GTranslate supports).
				$targetLang = [System.IO.Path]::GetExtension([System.IO.Path]::GetFileNameWithoutExtension($dependentFile)).Substring(1, 2);
				
				$dependentElements=$dependentResources.Root.Elements("data");
				$l = New-Object "System.Collections.Generic.List[System.Xml.Linq.XElement]";
				$dependentElements | ForEach { $l.Add($_); };
				$elementsEnum = $l.GetEnumerator();
				
				"Translating using Google Translate: " + $dependentFile;
				
				$isJsResourceFile = isJsResourceFile ($dependentFile);
				while($elementsEnum.MoveNext()) {
					$count = 0;
					$sendRequest = $false;
					$url = $gturl + "&target=" + $targetLang;
					$curTranslatingList = New-Object "System.Collections.Generic.List[System.Xml.Linq.XElement]";
					
					$ret = addElementToTranslate $primaryElements ($elementsEnum.Current) $curTranslatingList $isJsResourceFile $retranslate ([ref] $url);
					$count += 1;
					$sendRequest = $sendRequest -bor $ret;
				
					$enumMoved = $true;
					#130 seems to be the upper limit on number of q parameters.
					while($url.Length -lt 1800 -band $enumMoved -eq $true -band $count -le 125) {
						if($elementsEnum.MoveNext()) {
							$ret = addElementToTranslate $primaryElements ($elementsEnum.Current) $curTranslatingList $isJsResourceFile $retranslate ([ref] $url);
							$count += 1;
							$sendRequest = $sendRequest -bor $ret;
						} else {
							$enumMoved = $false;
						}
					}			
					
					if($sendRequest) {
						downloadAndUpdateTranslations $url $curTranslatingList;
					}
				}
				
				[System.IO.File]::WriteAllText($dependentFile, $dependentResources.ToString(), [System.Text.Encoding]::UTF8);
				#saveXDocInUtf8 $dependentResources $dependentFile;
			#}
			
			$isJsResourceFile = isJsResourceFile ($dependentFile);
			$fullName = [System.IO.Path]::GetFileName($dependentFile);
			if(!$isJsResourceFile) {continue;}
			
			"Updating client-resource for: " + $dependentFile;
			$directory=[System.IO.Path]::GetDirectoryName($dependentFile);
			$dependentFileName=[System.IO.Path]::GetFileNameWithoutExtension($dependentFile);
			$language=[System.IO.Path]::GetExtension($dependentFileName);

			$jsFileName=[System.IO.Path]::GetFileNameWithoutExtension([System.IO.Path]::GetFileNameWithoutExtension($dependentFileName)) + $language + ".js";
			$jsPath=[System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($directory), $jsFileName);

			#if ((-bnot [System.IO.File]::Exists($jsPath))) { # -bor (([System.IO.File]::GetLastWriteTime($dependentFile)) -gt ([System.IO.File]::GetLastWriteTime($jsPath)))) {
				$d=New-Object "System.Collections.Generic.Dictionary[string, string]";
				$doc=[System.Xml.Linq.XDocument]::Load($dependentFile);
				foreach ($element in $doc.Root.Elements("data"))
				{
					$resValue=$element.Element("value").Value;
					if (-bnot [String]::IsNullOrEmpty($resValue))
					{
						$d.Add($element.Attribute("name").Value, $resValue);
					}
				}
				$s="Ext.ns('Rahul.locale');";
				$s += "if(!Rahul.locale.strings)Rahul.locale.strings={};";
				$s += "Ext.apply(Rahul.locale.strings, ";
				$s += $serializer.Serialize($d);
				$s += ");";
				ensureFileWritable ($jsPath);
				[System.IO.File]::WriteAllText($jsPath, $s, [System.Text.Encoding]::UTF8);
			#}
		}
	}
}
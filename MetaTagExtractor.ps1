#requires -version 2.0

[System.Reflection.Assembly]::LoadWithPartialName("System.Xml.Linq") | Out-Null;

function extractMetaTagsToPrimaryResources($files) {
	"Extracting Meta tags from files..."

	#These attributes are added to Resource files to enable localization for them.
	#Commented out width and height below, if needed make them localizable.
	$localizableAttributes = @("text", "html", "title", "icon", <#"width", "height", #> "fieldlabel", "emptytext", "boxlabel", "header", "loadingtext", "tooltip", "tooltip-text", "note", "HeaderText");
	#These attributes are automatically translated with Google Translate in secondary resource files.
	$translatableAttributes = @("text", "html", "title", "fieldlabel", "emptytext", "boxlabel", "loadingtext", "header", "tooltip", "tooltip-text", "note");
	
	#If you want an attribute to be translated only for specific tags, add the attribute to both $localizableAttributes and $translatableAttributes above.
	#Additionally, add a hash for it below with the hash value being an array of tags for which the attribute should be automatically translated.
	$conditionallyTranslatable = @{ 
									"header" = @("ext:column", "ext:booleancolumn", "ext:checkcolumn", "ext:templatecolumn")
									};
	
	$regexOptions = [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase;
	[Regex] $tagLocator=New-Object Regex ("<(\w[^\s]+)[^<>]+?meta:resourcekey=""(.+?)"".*?>", $regexOptions);
	[Regex] $attributeLocator=New-Object Regex ("\s+([\w\d-]+)=""(.*?)""", $regexOptions);
	
	foreach($file in $files) {
		"Extracting Meta tags from file: " + $file;

		$directory = [System.IO.Path]::GetDirectoryName($file);
		$fileName = [System.IO.Path]::GetFileName($file);
		
		$resourceFile = [System.IO.Path]::Combine($directory, "App_LocalResources\" + $fileName + ".resx");
		
		if([System.IO.File]::Exists($resourceFile) -eq $false) { continue; }
		
		$content = [System.IO.File]::ReadAllText($file);
		$doc = [System.Xml.Linq.XDocument]::Load($resourceFile);
		$resources = $doc.Root.Elements("data");
		
		foreach ($tagMatch in $tagLocator.Matches($content)) {
			$tagNameLower = $tagMatch.Groups[1].Value.ToLower();
			$metaResourceKey = $tagMatch.Groups[2].Value;

			foreach($attributeMatch in $attributeLocator.Matches($tagMatch.Value)) {
				$attributeName = $attributeMatch.Groups[1].Value;
				$attributeNameLower = $attributeName.ToLower();
				$attributeValue = $attributeMatch.Groups[2].Value;
								
				if($localizableAttributes -contains $attributeNameLower) {
					$conditionalTags = $conditionallyTranslatable[$attributeNameLower];
					if($conditionalTags -ne $null) {
						if ($conditionalTags -notcontains $tagNameLower) {
							continue;
						}
					}
					
					$resKey = $metaResourceKey + "." + $attributeName;
					$element = $null;
					foreach ($dataElement in $resources) { 
						if($dataElement.Attribute("name").Value -eq $resKey) {
							$element = $dataElement;
						}
					};
					
					if ($element -eq $null) {
						$xname = [System.Xml.Linq.XName]::Get("data");
						$element = New-Object System.Xml.Linq.XElement ($xname);
						$xname = [System.Xml.Linq.XName]::Get("name");
						$att = New-Object System.Xml.Linq.XAttribute ($xname, $resKey);
						$element.Add($att);
						$doc.Root.Add($element);
					}
					$valueEl = $element.Element("value");
					if ($valueEl -eq $null) {
						$xname = [System.Xml.Linq.XName]::Get("value");
						$valueEl = New-Object System.Xml.Linq.XElement ($xname);
						$element.Add($valueEl);
					}
					$valueEl.SetValue($attributeValue);
					
					$commentEl = $element.Element("comment");
					if ($commentEl -eq $null) {
						$xname = [System.Xml.Linq.XName]::Get("comment");
						$commentEl = New-Object System.Xml.Linq.XElement ($xname);
						$element.Add($commentEl);
					}
					
					if($translatableAttributes -contains $attributeNameLower) {
						$commentEl.SetValue("");
					} else {
						$commentEl.SetValue("NT");
					}
				}				
			}
		}
		
		ensureFileWritable ($resourceFile);
		[System.IO.File]::WriteAllText($resourceFile, $doc.ToString(), [System.Text.Encoding]::UTF8);
		#saveXDocInUtf8 $doc $resourceFile;
	}
}


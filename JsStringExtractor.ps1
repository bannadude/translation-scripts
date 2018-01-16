#requires -version 2.0

[System.Reflection.Assembly]::LoadWithPartialName("System.Xml.Linq") | Out-Null;

function extractTranslatableStringsToPrimaryResources($files) {
	"Extracting translatable strings from javascript files..."
	
	foreach($file in $files) {
		"Extracting translatable strings from file: " + $file;
				
		$directory = [System.IO.Path]::GetDirectoryName($file);
		$fileName = [System.IO.Path]::GetFileName($file);
		
		$resourceFileDir = [System.IO.Path]::Combine($directory, "App_LocalResources");
		if ([System.IO.Directory]::Exists($resourceFileDir) -eq $false) { continue; }

		$resourceFileName = [System.IO.Path]::Combine($resourceFileDir, $fileName + ".resx");
		
		#Try to find a javascript resource file specific to this filename.
		if ([System.IO.File]::Exists($resourceFileName) -eq $false) {
		
			#Otherwise use the first available javascript resource file.
			$jsResourceFiles = [System.IO.Directory]::GetFiles($resourceFileDir, "*.js.resx");
			
			if($jsResourceFiles.Length -eq 0) { continue; }
			else { $resourceFileName = $jsResourceFiles[0]; }
		}

		$pattern = "Rahul.t(" + 
		               "((?<Open>\()[^\(\)]*)+" +
		               "((?<Close-Open>\))[^\(\)]*?)+" +
		             ")+?" +
		             "(?(Open)(?!))";

		$input = [System.IO.File]::ReadAllText($file);
		$matches = [Regex]::Matches($input, $pattern);
		
		if($matches.Count -gt 0) {
			$doc = [System.Xml.Linq.XDocument]::Load($resourceFileName);
			$resources = $doc.Root.Elements("data");
			$delimterArray = "`"'".ToCharArray();

			$dict = New-Object "System.Collections.Generic.Dictionary[string, string]";
			
			$matches | ForEach-Object {
				$matchStr = $_.ToString();
				
				$start = $matchStr.IndexOfAny($delimterArray);
				$end = $matchStr.LastIndexOfAny($delimterArray);
				$matchStr = $matchStr.Substring($start + 1, $end - $start - 1);
				
				$dict[$matchStr] = "";
			}
			
			foreach ($resKey in $dict.Keys) {
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
			}
		
			ensureFileWritable ($resourceFileName);
			[System.IO.File]::WriteAllText($resourceFileName, $doc.ToString(), [System.Text.Encoding]::UTF8);
		}
	}
}

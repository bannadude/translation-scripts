#requires -version 2.0

function addMetaTagsInFiles($files) {
	"Adding Meta tags to files..."

	#Meta tags are automatically added to elements which have an ID attribute, and meta:resourcekey equals ID for these tags.
	#Additionally, auto generated meta:resourcekey attributes would be added to tags below even if they do not have an id specified.
	$additionalNonIdTags = @("ext:gridcommand", "ext:compositefield", "ext:button", "ext:panel", "ext:displayfield", "ext:label",
								"ext:column", "ext:booleancolumn", "ext:checkcolumn", "ext:templatecolumn", "ext:ToolTip",
								"launcher","asp:BoundField","asp:TemplateField");
	
	$regexOptions = [System.Text.RegularExpressions.RegexOptions]::Singleline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase;
	[Regex] $tagLocator=New-Object Regex ("<\w[^>]+?>", $regexOptions);
	#[Regex] $idLocator=New-Object Regex (" ID=""(.*?)"".+?(?(meta:resourcekey)(meta:resourcekey=""(.*?)"")|(.*))", $regexOptions);
	[Regex] $idLocator=New-Object Regex ("\sID=""(.+?)""((.+?meta:resourcekey=""(.+?)"")|.*?)", $regexOptions);
	[Regex] $tagNameExtractor=New-Object Regex ("<([^\s]+?)\s+.*?(runat=""server"")?", $regexOptions);
	[Regex] $autoMetaIdExtractor=New-Object Regex ("=""AutoMetaId(\d+)""", $regexOptions);
	
	foreach($file in $files) {
		"Adding Meta tags to file: " + $file;
		
		$content = [System.IO.File]::ReadAllText($file);
		
		$maxMetaId = 0;
		foreach ($autoMetaMatch in $autoMetaIdExtractor.Matches($content)) {
			$autoId = [Int32]::Parse($autoMetaMatch.Groups[1].Value);
			if($autoId -gt $maxMetaId) { $maxMetaId = $autoId; }
		}
		
		$tagMatches = $tagLocator.Matches($content);
		for($i = $tagMatches.Count - 1; $i -ge 0; $i--) {
			$tagMatch = $tagMatches[$i];
			$tag = $tagMatch.ToString();
			
			$idMatch = $idLocator.Match($tag);
			if($idMatch.Success -eq $false) {
				$tagNameMatch = $tagNameExtractor.Match($tag);
				if($tagNameMatch.Success -eq $true) {
					#Already has an AutoMetaId.
					if($autoMetaIdExtractor.IsMatch($tag) -eq $true) { continue; }
					
					$tagName = $tagNameMatch.Groups[1].Value;
					if($additionalNonIdTags -notcontains $tagName.ToLower()) {continue;}
					
					$index = $null;
					if ($tagNameMatch.Groups[2].Success -eq $true) {
						$index = $tagNameMatch.Groups[2].Index + $tagNameMatch.Groups[2].Length;
					} else {
						$index = $tagNameMatch.Groups[1].Index + $tagNameMatch.Groups[1].Length;
					}
					
					$maxMetaId += 1;
					$tag = $tag.Insert($index, " meta:resourcekey=""AutoMetaId" + $maxMetaId + """");
				
					$content = $content.Remove($tagMatch.Index, $tagMatch.Length).Insert($tagMatch.Index, $tag);
				}
			} else {
			
				$group = $idMatch.Groups[4];
				if($group.Success) {
					#Already has a meta:resourcekey attribute.
					$tag = $tag.Remove($group.Index, $group.Length).Insert($group.Index, $idMatch.Groups[1].Value);
				} else {
					#Need to add the meta:resourcekey attribute.
					$group = $idMatch.Groups[1];
					$tag = $tag.Insert($group.Index + $group.Length + 1, " meta:resourcekey=""" + $group.Value + """");
				}
				
				$content = $content.Remove($tagMatch.Index, $tagMatch.Length).Insert($tagMatch.Index, $tag);
			}
		}
		
		ensureFileWritable ($file);		
		[System.IO.File]::WriteAllText($file, $content, [System.Text.Encoding]::UTF8);
	}
}

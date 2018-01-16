#requires -version 2.0

[System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions") | Out-Null;

$serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer;
$method = [System.Web.Script.Serialization.JavaScriptSerializer].GetMethod("Deserialize");
$deserializeMethod = $method.MakeGenericMethod([System.Collections.Generic.Dictionary[string, [Object]]]);
Remove-Variable $method;

function isJsResourceFile ([string] $path) {
	$fileName = [System.IO.Path]::GetFileName($path);
	return ([Regex]::IsMatch($fileName, ".*\.js\.\w+\.resx"));
}

function ensureFileWritable ([string] $path){
	[System.IO.File]::SetAttributes($path, [System.IO.File]::GetAttributes($path) -band (-bnot [System.IO.FileAttributes]::ReadOnly));	
}

function saveXDocInUtf8 ($doc, $path){
	$settings = New-Object System.Xml.XmlWriterSettings;
	$settings.Encoding = New-Object System.Text.UTF8Encoding;
	$writer = [System.Xml.XmlWriter]::Create($path, $settings);
	$doc.Save($writer);
}

function downloadAndUpdateTranslations ($url, $xElements) {
	try {
		$wc = New-Object Net.WebClient;
		$wc.Encoding = [System.Text.Encoding]::UTF8;
		$json = $wc.DownloadString($url);
		
		$d = $deserializeMethod.Invoke($serializer, $json);
		$d = $d["data"];
		$d = $d["translations"];
		
		$i = 0;
		foreach($pair in $d){
			$translations = $pair.Values;
			
			$translationsEnum = $translations.GetEnumerator();
			if($translationsEnum.MoveNext()){
				$translation = $translationsEnum.Current;
				$element = $xElements[$i];
				$element.Element("value").SetValue($translation);
				
				$comment = $element.Element("comment");
				if ($comment -eq $null) {
					$xname = [System.Xml.Linq.XName]::Get("comment");
					$comment = New-Object System.Xml.Linq.XElement ($xname);
					$element.Add($comment);
				}
				$comment.SetValue("Translated");
			}					
			$i += 1;
		}
	} catch [System.Net.WebException] {
		#TODO: Exception handling here.
		#Write-Host $_.Exception.ToString()
		
		Write-Host "`nAn exception occured translating strings using Google Translate. Exception Message:";
		Write-Host $_.Exception.ToString();
		Write-Host "`nAn exception occured translating strings using Google Translate. The exception url was:";
		Write-Host ($url + "`n`n");
	}
}

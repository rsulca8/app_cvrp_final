<?php

# This grabs the keyword off the url -- index.php?keyword=Clouds
$keyword = $_GET['keyword'];

# Only do this if we've already passed in a keyword (i.e. it's not blank)
if($keyword != "") {
	# Load the data from Google via cURL
		$curl_handle = curl_init();
		curl_setopt($curl_handle,CURLOPT_URL,"http://ajax.googleapis.com/ajax/services/search/images?v=1.0&imgsz=icon&q=".$keyword);
		curl_setopt($curl_handle, CURLOPT_RETURNTRANSFER, 1);
		$contents = curl_exec($curl_handle);
		curl_close($curl_handle);
		
	
	$images = string_extractor($contents, 'unescapedUrl":"', '",');
	
	$image_str = "";
	
	foreach($images as $image) {
		$image_str .= "<img src='".$image."' class='graphic-choice graphic-search-image'>";
	}	
}

/*-------------------------------------------------------------------------------------------------
Returns array of strings found between two target strings
-------------------------------------------------------------------------------------------------*/
function string_extractor($string,$start,$end) {
													
	# Setup
		$cursor = 0;
		$foundString             = -1; 
		$stringExtractor_results = Array();
	 			 		
	# Extract  		
	while($foundString != 0) {
		$ini = strpos($string,$start,$cursor);
				
		if($ini >= 0) {
			$ini    += strlen($start);
			$len     = strpos($string,$end,$ini) - $ini;
			$cursor  = $ini;
			$result  = substr($string,$ini,$len);
			array_push($stringExtractor_results,$result);
			$foundString = strpos($string,$start,$cursor);	
		}
		else {
			$foundString = 0;
		}
	}
	
	return $stringExtractor_results;
	
}

?>


<?=$image_str?>



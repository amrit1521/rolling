<?php
$APITOKEN = "PUT THE API TOKEN HERE";
$url = 'https://www.huntintool.com/api/v1/points/client/state';
$data = array(
	'token' => $APITOKEN,
	'state' => 'Colorado',
	'dob' => '1946-02-08',
	'last_name' => 'Alderson',
	'mail_postal' => '96073'
);

try {
    $result = request($url, $data);
    echo "Returned result:\n";
    var_dump($result);
} catch (Exception $e) {
    echo "Recieved an error:\n";
    echo "Code:" . $e->getCode() . "\n";
    echo "Message:" . $e->getMessage() . "\n";
}

function request($url, $data) {
    $result = "";

	$ch = curl_init(); // create cURL handle (ch)
	if (!$ch) {
	    throw new Exception("Couldn't initialize a cURL handle", 100);
	}

	// set some cURL options
	curl_setopt($ch, CURLOPT_URL,            $url);
	curl_setopt($ch, CURLOPT_HEADER,         0);
	curl_setopt($ch, CURLOPT_FOLLOWLOCATION, 1);
	curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
	curl_setopt($ch, CURLOPT_TIMEOUT,        30);
	curl_setopt($ch, CURLOPT_POSTFIELDS,     http_build_query($data));

	// execute
	$ret = curl_exec($ch);

    $info = curl_getinfo($ch);
    curl_close($ch); // close cURL handler

	if (empty($ret)) {
	    // some kind of an error happened
	    throw new Exception(curl_error($ch), 101);
	} else {

	    if (empty($info['http_code'])) {
	    	throw new Exception("No HTTP code was returned", 102);
	    } else if ($info['http_code'] !== 200) {
	        throw new Exception($ret, $info['http_code']);
	    } else {
            $result = json_decode($ret, true);
	    }

	}

    return $result;
}

?>

<?php

/*Check Encrypt Password*/

function hash_password_check($plain_password, $password_hashed) {
	require_once(__DIR__.'/class-phpass.php');

	$wp_hasher = new PasswordHash(8, TRUE);
	
	if($wp_hasher->CheckPassword($plain_password, $password_hashed)) {
	    echo "YES";
	} else {
	    echo "No, Wrong Password";
	}
}

hash_password_check($argv[1], $argv[2]);


/*Encrypt Password*/

function hash_password($password) {
	    global $wp_hasher;

 
    if ( empty($wp_hasher) ) {

	require_once(__DIR__.'/class-phpass.php');

        // By default, use the portable hash from phpass
        $wp_hasher = new PasswordHash(8, true);
    }

    return $wp_hasher->HashPassword( trim( $password ) );
}


function test() {
	require_once(__DIR__.'/class-phpass.php');

	$wp_hasher = new PasswordHash(8, TRUE);

	$password_hashed = '$P$BA849YEN6dR6jxRcrdf0gnEgReg0Pd1';
	$plain_password = 'rbo2016hunt';


	if($wp_hasher->CheckPassword($plain_password, $password_hashed)) {
		echo "YES, Matched";
	} else {
		echo "No, Wrong Password";
	}
	echo '<br> Plain Text: '.$plain_password;
	echo '<br> Password Hashed: '.$password_hashed;
}


?>
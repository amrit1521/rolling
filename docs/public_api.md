# GotMyTag Points API
*Version 1.0.3*

## About this document
All requests should be sent as https requests to host `www.huntintool.com`
This is a first go at the API documentation.  If you have any questions, please email ryan@codershop.com.  All parameters names surrounded with brackets like [dob] mean this parameter is not required in all requests, but it may be required under certain circomstances.  Those circumstances should be documented.  If they are not clearly documented, please ask.

<a name="general"></a>
## API Information

#### Error format
All errors are returned as JSON objects in the following format:

	{"error":"This is the error message","code": 1234}

#### Error http status codes
It's easy to know when an error occurs because all errors are returned with an http status code other than 200.  An appropriate http status code is used when applicable.  An example would be: If a request is made without sending the required token, the following response will be sent:

**Status Code:** 401 Unauthorized

**Response:** `{"error":"Unauthorized","code":401}`


<br>
<br>
# Endpoint Index

| Title |  Description |
| -- | -- |
| [Points By Client and State](#points_client_state) | Returns a client's points for the state specified

<br>
<br>
<a name="points_client_state"></a>
## Points By Client and State
### Request

**Method:** POST

**URL:** /api/v1/points/client/state
###### Parameters
| Name | Description |
| -- | -- |
| token | The API token supplied by GotMyTag |
| state | The state for which you want the points |
| [clientId] | The HuntinFool client ID.  This is optional, but will be recorded if sent. |

Depending on which state you specify, there are other required parameters:

* Arizona:

	| Name | Description |
	| -- | -- |
	| ssn | Social Security Number or Arizona Department ID |
	| dob | Date of birth |

* California:

	| Name | Description |
	| -- | -- |
	| dob | Date of birth |
	| dl_state | State where the driver's license was issued |
	| drivers_license | Driver's license number |
	| last_name | Last name |

* Colorado:

	| Name | Description |
	| -- | -- |
	| dob | Date of birth |
	| last_name | Last name |
	| mail_postal | The client's zip code |

* Florida:
Need to complete the fields

	| Name | Description |
	| -- | -- |
	| dob | Date of birth |
	| last_name | Last name |
	| mail_postal | The client's zip code |

* Montana:

	| Name | Description |
	| -- | -- |
	| first_name | First name |
	| last_name | Last name |
	| dob | Date of birth |
	| mail_postal | The client's zip code |

* Nevada:

	| Name | Description |
	| -- | -- |
	| [ssn \| cid] | Social Security Number or Nevada Sportsman's ID |
	| dob | Date of birth |

* Oregon:

	| Name | Description |
	| -- | -- |
	| cid | Oregon Hunter ID |
	| dob | Date of birth |
	| last_name | Last name |

* Pennsylvania:

	| Name | Description |
	| -- | -- |
	| cid \| (drivers_license && dl_state) \| ssn | Pennsylvania CID or Driver's license and state or Social Security Number|
	| dob | Date of birth |

* Utah:

	| Name | Description |
	| -- | -- |
	| [ssn \| cid] | Social Security Number or Utah Customer ID |
	| dob | Date of birth |

* Washington:

	| Name | Description |
	| -- | -- |
	| last_name | Last name |
	| dob | Date of birth |
	| One of the following:|
	| [cid] | Washington Wild ID |
	| [ssn] | Social Security Number |
	| Or |
	| dl_state | State where the driver's license was issued |
	| drivers_license | Driver's license number |

	*The request must include the Washington Wild ID or the Client's social secuity number or the Client's Driver's license and state in which the license was issued.*

* Wyoming:

	| Name | Description |
	| -- | -- |
	| first_name | First name |
	| last_name | Last name |
	| dob | Date of birth |
	| mail_postal | The client's zip code |

**Curl Example:**

	curl -X POST --data "token=[PUT TOKEN HERE]&state=Utah&dob=2014-01-01&cid=123456" https://www.huntintool.com/api/v1/points/client/state


### Response
<br>
**Example (formated for readability):**

    [
        {
            "animal": "Deer",
            "points": "2",
            "weight": "0"
        },
        {
            "animal": "Pronghorn",
            "points": "10",
            "weight": "0"
        },
        {
            "animal": "Elk",
            "points": "3",
            "weight": "0"
        }
    ]

* *The weight field is only returned if they state has weighted points.  For now this is only in Colorado*
* *If an empty array is returned, it means the client's account in the specified state was found, but they have no points.*

#### Errors

| HTTP Status Code| Message      | Description |
| --------------- | ------------ | ----------- |
| 400             | Points are not provided for this state | Points are not provided for the state specified.  Check the spelling. |
| 401             | Unauthorized | No token, or the wrong token was sent. |
| 500 | Unable to connect to state | The system was unable to connect to the state's website, or the connection to the state's website was lost.
| 500 | System error | Something unexpected happened.  Please report this to ryan@codershop.com |

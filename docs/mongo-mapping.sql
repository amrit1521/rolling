-- List foreign tables
-- \dET+

DROP USER MAPPING FOR postgres SERVER mongo_server;
DROP SERVER mongo_server;
DROP EXTENSION multicorn;

-- load extension first time after install
CREATE EXTENSION multicorn;

-- mongo --host db1.gotmytag.com --port 27017 -u postgres -p GotMyTag11 huntintool

-- create server object
CREATE SERVER mongo_server
FOREIGN DATA WRAPPER multicorn
OPTIONS (wrapper 'yam_fdw.Yamfdw');

-- db.createUser(
--    {
--      user: "postgres",
--      pwd: "GotMyTag11",
--      roles: [ {role: "readWrite", db: "huntintool"} ]
--    }
-- )


-- applications
DROP TYPE IF EXISTS application_status;
CREATE TYPE application_status AS ENUM ('saved', 'review_requested', 'review_ready', 'reviewed', 'purchase_requested', 'purchased', 'error');
DROP FOREIGN TABLE IF EXISTS applications;
CREATE FOREIGN TABLE applications (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "clientId" TEXT,
    "huntId" VARCHAR OPTIONS (type 'ObjectId'),
    "huntIds" VARCHAR ARRAY OPTIONS (type 'ObjectId'),
    "license" TEXT,
    "licenses" TEXT,
    "name" TEXT,
    "receipt" TEXT,
    "resultBody" TEXT,
    "review_html" TEXT,
    "review_file" TEXT,
    "stateId"VARCHAR OPTIONS (type 'ObjectId'),
    "timestamp" TIMESTAMPTZ,
    "tenantId"VARCHAR OPTIONS (type 'ObjectId'),
    "total" NUMERIC,
    "transactionId" TEXT,
    "userId"VARCHAR OPTIONS (type 'ObjectId'),
    "year" TEXT,
    "cardIndex" TEXT,
    "cardTitle" TEXT,
    "status" application_status,
    "error" TEXT,
    "lastPage" TEXT
)
SERVER mongo_server
OPTIONS (
    collection 'applications',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);


-- azportalaccounts
DROP FOREIGN TABLE IF EXISTS azportalaccounts;
CREATE FOREIGN TABLE azportalaccounts (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "userId" VARCHAR OPTIONS (type 'ObjectId'),
    "clientId" TEXT,
    "first_name" TEXT,
    "last_name" TEXT,
    "tenantId" VARCHAR OPTIONS (type 'ObjectId'),
    "azUsername" TEXT,
    "azPassword" TEXT,
    "azAcctReqSent" BOOLEAN,
    "azAcctLoginValidated" BOOLEAN,
    "azAcctProfilePopulated" BOOLEAN,
    "azAcctNeedsUpdated" BOOLEAN,
    "azAcctNeedsReActivated" BOOLEAN,
    "departmentId" TEXT,
    "license_expiration" TIMESTAMPTZ,
    "license_number" TEXT,
    "license_type" TEXT,
    "license_departmentId" TEXT,
    "modified" TIMESTAMPTZ,
    "notes" TEXT,
    "updatePortalAccountStatus" TEXT
)
SERVER mongo_server
OPTIONS (
    collection 'azportalaccounts',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);


-- drawresults
DROP FOREIGN TABLE IF EXISTS drawresults;
CREATE FOREIGN TABLE drawresults (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "name" TEXT,
    "unit" TEXT,
    "status" TEXT,
    "year" TEXT,
    "stateId" VARCHAR OPTIONS (type 'ObjectId'),
    "userId" VARCHAR OPTIONS (type 'ObjectId'),
    "notified" BOOLEAN,
    "tenantId" VARCHAR OPTIONS (type 'ObjectId'),
    "notes" TEXT,
    "createdAt" TIMESTAMPTZ
)
SERVER mongo_server
OPTIONS (
    collection 'drawresults',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- emailtemplates
DROP FOREIGN TABLE IF EXISTS emailtemplates;
CREATE FOREIGN TABLE emailtemplates (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "code" TEXT,
    "html" TEXT,
    "subject" TEXT,
    "text" TEXT,
    "title" TEXT
)
SERVER mongo_server
OPTIONS (
    collection 'emailtemplates',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- globals
DROP FOREIGN TABLE IF EXISTS globals;
CREATE FOREIGN TABLE globals (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "created" TIMESTAMPTZ,
    "key" TEXT,
    "modified" TIMESTAMPTZ,
    "value" TEXT
)
SERVER mongo_server
OPTIONS (
    collection 'globals',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- huntcatalogs
DROP TYPE IF EXISTS huntcatalogs_type;
CREATE TYPE huntcatalogs_type AS ENUM ('hunt', 'course', 'product');
DROP TYPE IF EXISTS huntcatalogs_paymentplan;
CREATE TYPE huntcatalogs_paymentplan AS ENUM ('hunt', 'full', 'months');
DROP FOREIGN TABLE IF EXISTS hun;
CREATE FOREIGN TABLE hun (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "huntNumber" TEXT,
    "title" TEXT,
    "outfitter_userId" VARCHAR OPTIONS (type 'ObjectId'),
    "outfitter_name" TEXT,
    "tenantId" VARCHAR OPTIONS (type 'ObjectId'),
    "isActive" BOOLEAN,
    "isHuntSpecial" BOOLEAN,
    "memberDiscount" BOOLEAN,
    "country" TEXT,
    "state" TEXT,
    "area" TEXT,
    "species" TEXT,
    "weapon" TEXT,
    "price" NUMERIC,
    "startDate" TIMESTAMPTZ,
    "endDate" TIMESTAMPTZ,
    "internalNotes" TEXT,
    "pricingNotes" TEXT,
    "description" TEXT,
    "huntSpecialMessage" TEXT,
    "classification" TEXT,
    "createMember" BOOLEAN,
    "createRep" BOOLEAN,
    "updatedAt" TIMESTAMPTZ,
    "createdAt" TIMESTAMPTZ,
    "status" TEXT,
    "type" huntcatalogs_type,
    "paymentPlan" huntcatalogs_paymentplan,
    "media" TEXT
)
SERVER mongo_server
OPTIONS (
    collection 'hun',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- huntchoices
DROP FOREIGN TABLE IF EXISTS huntchoices;
CREATE FOREIGN TABLE huntchoices (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "choices" TEXT,
    "hunt" TEXT,
    "preferecePoint" BOOLEAN,
    "huntId" VARCHAR OPTIONS (type 'ObjectId'),
    "stateId" VARCHAR OPTIONS (type 'ObjectId'),
    "userId" VARCHAR OPTIONS (type 'ObjectId')
)
SERVER mongo_server
OPTIONS (
    collection 'huntchoices',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- huntinfoolclients
DROP FOREIGN TABLE IF EXISTS huntinfoolclients;
CREATE FOREIGN TABLE huntinfoolclients (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "billing1_address" TEXT,
    "billing1_address2" TEXT,
    "billing1_city" TEXT,
    "billing1_state" TEXT,
    "billing1_zip" TEXT,
    "billing1_country" TEXT,
    "billing1_phone" TEXT,
    "billing2_address" TEXT,
    "billing2_address2" TEXT,
    "billing2_city" TEXT,
    "billing2_state" TEXT,
    "billing2_zip" TEXT,
    "billing2_country" TEXT,
    "billing2_phone" TEXT,
    "ca_id" TEXT,
    "client_id" TEXT,
    "co_conservation" TEXT,
    "contact_email" TEXT,
    "driver_license" TEXT,
    "driver_license_state" TEXT,
    "duals_last" TEXT,
    "duals_name" TEXT,
    "duals_number" TEXT,
    "eyes" TEXT,
    "field1" TEXT,
    "field2" TEXT,
    "field3" TEXT,
    "field4" TEXT,
    "field5" TEXT,
    "field6" TEXT,
    "field7" TEXT,
    "field8" TEXT,
    "field9" TEXT,
    "field10" TEXT,
    "field11" TEXT,
    "field12" TEXT,
    "field13" TEXT,
    "needEncryptCC" BOOLEAN,
    "gender" TEXT,
    "hair" TEXT,
    "height" TEXT,
    "hunter_ed" TEXT,
    "hunter_ed_state" TEXT,
    "hunting_comments" TEXT,
    "ia_conservation" TEXT,
    "ks_number" TEXT,
    "mail_address" TEXT,
    "mail_city" TEXT,
    "mail_country" TEXT,
    "mail_county" TEXT,
    "mail_state" TEXT,
    "mail_zip" TEXT,
    "physical_address" TEXT,
    "physical_city" TEXT,
    "physical_country" TEXT,
    "physical_county" TEXT,
    "physical_state" TEXT,
    "physical_zip" TEXT,
    "member_id" TEXT,
    "modified" TIMESTAMPTZ,
    "mtals" TEXT,
    "nm_cin" TEXT,
    "nmfst" TEXT,
    "nmlt" TEXT,
    "nmmd" TEXT,
    "ore_hunter" TEXT,
    "phone_cell" TEXT,
    "phone_day" TEXT,
    "phone_evening" TEXT,
    "tl" TEXT,
    "tx_id" TEXT,
    "userId" VARCHAR OPTIONS (type 'ObjectId'),
    "tenantId" VARCHAR OPTIONS (type 'ObjectId'),
    "weapons_mstr" TEXT,
    "weight" TEXT,
    "wild" TEXT,
    "wy_id" TEXT
)
SERVER mongo_server
OPTIONS (
    collection 'huntinfoolclients',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- huntinfoolgroups
DROP FOREIGN TABLE IF EXISTS huntinfoolgroups;
CREATE FOREIGN TABLE huntinfoolgroups (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "leader" TEXT,
    "members" TEXT
)
SERVER mongo_server
OPTIONS (
    collection 'huntinfoolgroups',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- huntinfoolloaddobs
DROP FOREIGN TABLE IF EXISTS huntinfoolloaddobs;
CREATE FOREIGN TABLE huntinfoolloaddobs (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "member_id" TEXT,
    "first_name" TEXT,
    "last_name" TEXT,
    "mail_address" TEXT,
    "mail_city" TEXT,
    "mail_state" TEXT,
    "mail_zip" TEXT,
    "dob" TEXT
)
SERVER mongo_server
OPTIONS (
    collection 'huntinfoolloaddobs',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- huntinfoolloadgenerics
DROP FOREIGN TABLE IF EXISTS huntinfoolloadgenerics;
CREATE FOREIGN TABLE huntinfoolloadgenerics (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "member_id" TEXT,
    "state" TEXT,
    "cid" TEXT,
    "notes" TEXT
)
SERVER mongo_server
OPTIONS (
    collection 'huntinfoolloadgenerics',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- huntinfoolloadnodobdrawresults
DROP FOREIGN TABLE IF EXISTS huntinfoolloadnodobdrawresults;
CREATE FOREIGN TABLE huntinfoolloadnodobdrawresults (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "memberId" TEXT,
    "hfLoadNoDOBId" VARCHAR OPTIONS (type 'ObjectId'),
    "first_name" TEXT,
    "last_name" TEXT,
    "mail_address" TEXT,
    "mail_city" TEXT,
    "mail_state" TEXT,
    "mail_postal" TEXT,
    "city" TEXT,
    "huntName" TEXT,
    "unit" TEXT,
    "status" TEXT,
    "year" TEXT,
    "stateId" VARCHAR OPTIONS (type 'ObjectId'),
    "tenantId" VARCHAR OPTIONS (type 'ObjectId'),
    "modified" TIMESTAMPTZ,
    "userName" TEXT
)
SERVER mongo_server
OPTIONS (
    collection 'huntinfoolloadnodobdrawresults',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- huntinfoolloadnodobs
DROP FOREIGN TABLE IF EXISTS huntinfoolloadnodobs;
CREATE FOREIGN TABLE huntinfoolloadnodobs (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "memberId" TEXT,
    "first_name" TEXT,
    "last_name" TEXT,
    "mail_address" TEXT,
    "mail_city" TEXT,
    "mail_state" TEXT,
    "mail_postal" TEXT,
    "dob" TEXT
)
SERVER mongo_server
OPTIONS (
    collection 'huntinfoolloadnodobs',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- huntinfoolstates
DROP FOREIGN TABLE IF EXISTS huntinfoolstates;
CREATE FOREIGN TABLE huntinfoolstates (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "userId" VARCHAR OPTIONS (type 'ObjectId'),
    "tenantId" VARCHAR OPTIONS (type 'ObjectId'),
    "client_id" TEXT,
    "modified" TIMESTAMPTZ,
    "gen_notes" TEXT,
    "ak_check" TEXT,
    "ak_comments" TEXT,
    "ak_notes" TEXT,
    "ak_species" TEXT,
    "az_check" TEXT,
    "az_comments" TEXT,
    "az_license" TEXT,
    "az_notes" TEXT,
    "az_species" TEXT,
    "ca_check" TEXT,
    "ca_comments" TEXT,
    "ca_notes" TEXT,
    "ca_species" TEXT,
    "co_check" TEXT,
    "co_comments" TEXT,
    "co_notes" TEXT,
    "co_species" TEXT,
    "fl_check" TEXT,
    "fl_notes" TEXT,
    "fl_species" TEXT,
    "ia_check" TEXT,
    "ia_comments" TEXT,
    "ia_notes" TEXT,
    "ia_species" TEXT,
    "id_check" TEXT,
    "id_comments" TEXT,
    "id_notes" TEXT,
    "id_species_1" TEXT,
    "id_species_3" TEXT,
    "ks_check" TEXT,
    "ks_comments" TEXT,
    "ks_mule_deer_stamp" TEXT,
    "ks_notes" TEXT,
    "ks_species" TEXT,
    "mt_check" TEXT,
    "mt_comments" TEXT,
    "mt_notes" TEXT,
    "mt_species" TEXT,
    "nd_check" TEXT,
    "nd_notes" TEXT,
    "nd_species" TEXT,
    "nm_check" TEXT,
    "nm_comments" TEXT,
    "nm_notes" TEXT,
    "nm_species" TEXT,
    "nv_check" TEXT,
    "nv_comments" TEXT,
    "nv_notes" TEXT,
    "nv_species" TEXT,
    "ore_check" TEXT,
    "ore_comments" TEXT,
    "ore_notes" TEXT,
    "ore_species" TEXT,
    "sd_check" TEXT,
    "sd_notes" TEXT,
    "sd_species" TEXT,
    "tx_check" TEXT,
    "tx_notes" TEXT,
    "tx_species" TEXT,
    "ut_check" TEXT,
    "ut_comments" TEXT,
    "ut_notes" TEXT,
    "ut_species_1" TEXT,
    "ut_species_2" TEXT,
    "wa_check" TEXT,
    "wa_comments" TEXT,
    "wa_notes" TEXT,
    "wa_species" TEXT,
    "wy_check" TEXT,
    "wy_comments" TEXT,
    "wy_notes" TEXT,
    "wy_species" TEXT
)
SERVER mongo_server
OPTIONS (
    collection 'huntinfoolstates',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- huntinfoolusers
DROP FOREIGN TABLE IF EXISTS huntinfoolusers;
CREATE FOREIGN TABLE huntinfoolusers (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "member_id" TEXT,
    "first_name" TEXT,
    "last_name" TEXT,
    "mail_address" TEXT,
    "mail_city" TEXT,
    "mail_state" TEXT,
    "mail_zip" TEXT,
    "dob" TEXT,
    "uniqueid" TEXT,
    "residence" TEXT,
    "userId" VARCHAR OPTIONS (type 'ObjectId'),
    "clientId" TEXT,
    "states" TEXT
)
SERVER mongo_server
OPTIONS (
    collection 'huntinfoolusers',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- huntoptions
DROP FOREIGN TABLE IF EXISTS huntoptions;
CREATE FOREIGN TABLE huntoptions (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "active" BOOLEAN,
    "data" TEXT,
    "huntId" VARCHAR OPTIONS (type 'ObjectId'),
    "stateId" VARCHAR OPTIONS (type 'ObjectId')
)
SERVER mongo_server
OPTIONS (
    collection 'huntoptions',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- hunts
DROP FOREIGN TABLE IF EXISTS hunts;
CREATE FOREIGN TABLE hunts (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "active" BOOLEAN,
    "name" TEXT,
    "params" TEXT,
    "match" TEXT,
    "groupable" BOOLEAN,
    "stateId" VARCHAR OPTIONS (type 'ObjectId')
)
SERVER mongo_server
OPTIONS (
    collection 'hunts',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- licenses
DROP FOREIGN TABLE IF EXISTS licenses;
CREATE FOREIGN TABLE licenses (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "stateId" VARCHAR OPTIONS (type 'ObjectId'),
    "transactionId" TEXT,
    "url" TEXT,
    "userId" VARCHAR OPTIONS (type 'ObjectId'),
    "year" TEXT
)
SERVER mongo_server
OPTIONS (
    collection 'licenses',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- messages
DROP FOREIGN TABLE IF EXISTS messages;
CREATE FOREIGN TABLE messages (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "key" TEXT,
    "type" TEXT,
    "source" TEXT,
    "sourceId" VARCHAR OPTIONS (type 'ObjectId'),
    "tenantId" VARCHAR OPTIONS (type 'ObjectId'),
    "sent" TIMESTAMPTZ,
    "state" TEXT,
    "reminderId" VARCHAR OPTIONS (type 'ObjectId')
)
SERVER mongo_server
OPTIONS (
    collection 'messages',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- notifications
DROP FOREIGN TABLE IF EXISTS notifications;
CREATE FOREIGN TABLE notifications (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "userId" VARCHAR OPTIONS (type 'ObjectId'),
    "message" TEXT,
    "created" TIMESTAMPTZ,
    "read" TIMESTAMPTZ
)
SERVER mongo_server
OPTIONS (
    collection 'notifications',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- points
DROP FOREIGN TABLE IF EXISTS points;
CREATE FOREIGN TABLE points (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "area" TEXT,
    "count" NUMERIC,
    "created" TIMESTAMPTZ,
    "eligibleDate" TEXT,
    "harvest" TEXT,
    "lastPoint" TEXT,
    "lastTagDate" TEXT,
    "name" TEXT,
    "reason" TEXT,
    "stateId" VARCHAR OPTIONS (type 'ObjectId'),
    "tenantId" VARCHAR OPTIONS (type 'ObjectId'),
    "userId" VARCHAR OPTIONS (type 'ObjectId'),
    "weight" NUMERIC
)
SERVER mongo_server
OPTIONS (
    collection 'points',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- purchases
DROP FOREIGN TABLE IF EXISTS purchases;
CREATE FOREIGN TABLE purchases (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "tenantId" VARCHAR OPTIONS (type 'ObjectId'),
    "userId" VARCHAR OPTIONS (type 'ObjectId'),
    "huntCatalogId" VARCHAR OPTIONS (type 'ObjectId'),
    "huntCatalogCopy" TEXT,
    "receipt" TEXT,
    "amount" NUMERIC,
    "amountPaid" NUMERIC,
    "createdAt" TIMESTAMPTZ,
    "purchaseNotes" TEXT,
    "paymentMethod" TEXT,
    "minPaymentRequired" NUMERIC,
    "basePrice" NUMERIC,
    "monthlyPayment" NUMERIC,
    "monthlyPaymentNumberMonths" NUMERIC,
    "userIsMember" BOOLEAN,
    "membershipPurchased" BOOLEAN,
    "userParentId" VARCHAR OPTIONS (type 'ObjectId'),
    "commission" NUMERIC,
    "cc_transId" TEXT,
    "cc_responseCode" TEXT,
    "cc_messageCode" TEXT,
    "cc_description" TEXT,
    "cc_name" TEXT,
    "cc_email" TEXT,
    "cc_phone" TEXT,
    "cc_number" TEXT
)
SERVER mongo_server
OPTIONS (
    collection 'purchases',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- refers
DROP FOREIGN TABLE IF EXISTS refers;
CREATE FOREIGN TABLE refers (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "ip" TEXT,
    "modified" TIMESTAMPTZ,
    "referrer" TEXT
)
SERVER mongo_server
OPTIONS (
    collection 'refers',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- reminders
DROP FOREIGN TABLE IF EXISTS reminders;
CREATE FOREIGN TABLE reminders (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "active" BOOLEAN,
    "end" TEXT,
    "isSheep" BOOLEAN,
    "start" TEXT,
    "state" TEXT,
    "title" TEXT,
    "startSubject" TEXT,
    "txtStart" TEXT,
    "txtEnd" TEXT,
    "appStart" TEXT,
    "appEnd" TEXT,
    "emailStartText" TEXT,
    "emailStart" TEXT,
    "endSubject" TEXT,
    "emailEndText" TEXT,
    "emailEnd" TEXT,
    "filter" TEXT,
    "tenantId" VARCHAR OPTIONS (type 'ObjectId'),
    "isDrawResultSuccess" BOOLEAN,
    "isDrawResultUnsuccess" BOOLEAN,
    "testCell" TEXT,
    "testEmail" TEXT,
    "testCellCarrier" TEXT,
    "testUserId" VARCHAR OPTIONS (type 'ObjectId'),
    "testDrawResultId" VARCHAR OPTIONS (type 'ObjectId'),
    "testLastMsg" TEXT
)
SERVER mongo_server
OPTIONS (
    collection 'reminders',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- servicerequests
DROP FOREIGN TABLE IF EXISTS servicerequests;
CREATE FOREIGN TABLE servicerequests (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "external_id" TEXT,
    "userId" VARCHAR OPTIONS (type 'ObjectId'),
    "clientId" TEXT,
    "memberId" TEXT,
    "tenantId" VARCHAR OPTIONS (type 'ObjectId'),
    "type" TEXT,
    "first_name" TEXT,
    "last_name" TEXT,
    "address" TEXT,
    "city" TEXT,
    "country" TEXT,
    "postal" TEXT,
    "state" TEXT,
    "email" TEXT,
    "phone" TEXT,
    "species" TEXT,
    "location" TEXT,
    "weapon" TEXT,
    "budget" TEXT,
    "referral_source" TEXT,
    "referral_ip" TEXT,
    "referral_url" TEXT,
    "message" TEXT,
    "notes" TEXT,
    "newsletter" BOOLEAN,
    "specialOffers" BOOLEAN,
    "external_date_created" TIMESTAMPTZ,
    "updatedAt" TIMESTAMPTZ,
    "lastFollowedUpAt" TIMESTAMPTZ,
    "contactDiffs" TEXT,
    "needsFollowup" BOOLEAN,
    "status" TEXT
)
SERVER mongo_server
OPTIONS (
    collection 'servicerequests',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- states
DROP FOREIGN TABLE IF EXISTS states;
CREATE FOREIGN TABLE states (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "active" BOOLEAN,
    "applicationReady" BOOLEAN,
    "applicationUrl" TEXT,
    "abbreviation" TEXT,
    "hasPoints" BOOLEAN,
    "idTitle" TEXT,
    "idRequired" BOOLEAN,
    "name" TEXT,
    "oddsUrl" TEXT,
    "pointsUrl" TEXT,
    "url" TEXT
)
SERVER mongo_server
OPTIONS (
    collection 'states',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- tenantemails
DROP FOREIGN TABLE IF EXISTS tenantemails;
CREATE FOREIGN TABLE tenantemails (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "tenantId" VARCHAR OPTIONS (type 'ObjectId'),
    "email_html" TEXT,
    "email_text" TEXT,
    "subject" TEXT,
    "timestamp" TIMESTAMPTZ,
    "type" TEXT,
    "enabled" BOOLEAN,
    "testUserId" VARCHAR OPTIONS (type 'ObjectId')
)
SERVER mongo_server
OPTIONS (
    collection 'tenantemails',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- tenants
DROP FOREIGN TABLE IF EXISTS tenants;
CREATE FOREIGN TABLE tenants (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "commission" NUMERIC,
    "domain" TEXT,
    "logo" TEXT,
    "name" TEXT,
    "url" TEXT,
    "ssl_issuer" TEXT,
    "ssl_key" TEXT,
    "ssl_pem" TEXT,
    "referralPrefix" TEXT,
    "clientPrefix" TEXT,
    "clientId_seq" NUMERIC
)
SERVER mongo_server
OPTIONS (
    collection 'tenants',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- tokens
DROP FOREIGN TABLE IF EXISTS tokens;
CREATE FOREIGN TABLE tokens (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "userId" VARCHAR OPTIONS (type 'ObjectId'),
    "token" TEXT,
    "expires" TIMESTAMPTZ
)
SERVER mongo_server
OPTIONS (
    collection 'tokens',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- users
DROP TYPE IF EXISTS users_imported;
CREATE TYPE users_imported AS ENUM ('HFMemberLoad', 'RBMemberImport', 'RBO_WordpressRequest', 'ZGFMemberImport');
DROP TYPE IF EXISTS users_source;
CREATE TYPE users_source AS ENUM ('Dashboard', 'IOS', 'Android');
DROP FOREIGN TABLE IF EXISTS users;
CREATE FOREIGN TABLE users (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "active" BOOLEAN,
    "clientId" TEXT,
    "commission" TEXT,
    "contractEnd" TIMESTAMPTZ,
    "createdAt" TIMESTAMPTZ,
    "demo" BOOLEAN,
    "devices" TEXT,
    "dob" TEXT,
    "drivers_license" TEXT,
    "dl_state" TEXT,
    "dl_issued" TEXT,
    "email" TEXT,
    "eyes" TEXT,
    "field1" TEXT,
    "field2" TEXT,
    "field3" TEXT,
    "field4" TEXT,
    "field5" TEXT,
    "field6" TEXT,
    "field7" TEXT,
    "field8" TEXT,
    "field9" TEXT,
    "field10" TEXT,
    "field11" TEXT,
    "field12" TEXT,
    "field13" TEXT,
    "files" TEXT,
    "first_name" TEXT,
    "gender" TEXT,
    "hair" TEXT,
    "heightFeet" TEXT,
    "heightInches" TEXT,
    "hunter_safety_number" TEXT,
    "hunter_safety_type" TEXT,
    "hunter_safety_state" TEXT,
    "alaska_license" TEXT,
    "alaska_license_year" TEXT,
    "idaho_license" TEXT,
    "idaho_license_year" TEXT,
    "isAdmin" BOOLEAN,
    "isMember"  BOOLEAN,
    "isOutfitter" BOOLEAN,
    "isRep"  BOOLEAN,
    "imported" users_imported,
    "internalNotes" TEXT,
    "last_name" TEXT,
    "locale" TEXT,
    "needsWelcomeEmail" BOOLEAN,
    "needsPointsEmail" BOOLEAN,
    "mail_address" TEXT,
    "mail_city" TEXT,
    "mail_country" TEXT,
    "mail_postal" TEXT,
    "mail_state" TEXT,
    "memberId" TEXT,
    "memberType" TEXT,
    "memberExpires" TIMESTAMPTZ,
    "memberStarted" TIMESTAMPTZ,
    "repExpires" TIMESTAMPTZ,
    "repStarted" TIMESTAMPTZ,
    "middle_name" TEXT,
    "name" TEXT,
    "occupation" TEXT,
    "parentId" VARCHAR OPTIONS (type 'ObjectId'),
    "parent_memberId" TEXT,
    "parent_clientId" TEXT,
    "password" TEXT,
    "phone_cell" TEXT,
    "phone_cell_carrier" TEXT,
    "phone_day" TEXT,
    "phone_home" TEXT,
    "physical_address" TEXT,
    "physical_city" TEXT,
    "physical_country" TEXT,
    "physical_postal" TEXT,
    "physical_state" TEXT,
    "powerOfAttorney" BOOLEAN,
    "reminders" TEXT,
    "referral" TEXT,
    "residence" TEXT,
    "res_months" NUMERIC,
    "res_years" NUMERIC,
    "source" users_source,
    "ssn" TEXT,
    "status" TEXT,
    "suffix" TEXT,
    "tenantId" VARCHAR OPTIONS (type 'ObjectId'),
    "timestamp" TIMESTAMPTZ,
    "type" TEXT,
    "modified" TIMESTAMPTZ,
    "username" TEXT,
    "weight" TEXT,
    "welcomeEmailSent" TIMESTAMPTZ,
    "pointsEmailSent" TIMESTAMPTZ,
    "azUsername" TEXT,
    "azPassword" TEXT,
    "sdUsername" TEXT,
    "sdPassword" TEXT,
    "nmUsername" TEXT,
    "nmPassword" TEXT,
    "idUsername" TEXT,
    "idPassword" TEXT,
    "waUsername" TEXT,
    "waPassword" TEXT,
    "coUsername" TEXT,
    "coPassword" TEXT,
    "mtUsername" TEXT,
    "mtPassword" TEXT,
    "nvUsername" TEXT,
    "nvPassword" TEXT,
    "dl_is_new" BOOLEAN
)
SERVER mongo_server
OPTIONS (
    collection 'users',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);


-- userstates
DROP FOREIGN TABLE IF EXISTS userstates;
CREATE FOREIGN TABLE userstates (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "stateId" VARCHAR OPTIONS (type 'ObjectId'),
    "userId" VARCHAR OPTIONS (type 'ObjectId'),
    "cid" TEXT
)
SERVER mongo_server
OPTIONS (
    collection 'userstates',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- views
DROP FOREIGN TABLE IF EXISTS views;
CREATE FOREIGN TABLE views (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    tenantId VARCHAR OPTIONS (type 'ObjectId'),
    userId VARCHAR OPTIONS (type 'ObjectId'),
    selector TEXT,
    name TEXT,
    admin_only BOOLEAN,
    options TEXT,
    description TEXT
)
SERVER mongo_server
OPTIONS (
    collection 'views',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

-- zipcodes
DROP FOREIGN TABLE IF EXISTS zipcodes;
CREATE FOREIGN TABLE zipcodes (
    "_id" VARCHAR OPTIONS (type 'ObjectId'),
    "code" TEXT,
    "state" TEXT,
    "city" TEXT,
    "county" TEXT,
    "lat" NUMERIC,
    "lon" NUMERIC
)
SERVER mongo_server
OPTIONS (
    collection 'zipcodes',
    db 'huntintool',
    host 'db1.gotmytag.com',
    password 'GotMyTag11',
    port '27017',
    "user" 'postgres'
);

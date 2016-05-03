SQL Executor Brick
==================
The brick executes SQL commands on the top of ADS. 

## Description
 
The brick provides simple way for SQL commands execution and orchestration. 

Supported features:
 
 * parallel execution of SQL statements
 * iteration over SQL statements
 * propagation of parameters from process schedule
 * propagation of parameters from ADS
 * simple orchestration 
 

## Limits

 * Whole process duration up to 5h
 * Single query duration up to 2h
 * Parameters read from ADS support up to 100 values

## Deployment

Manually by deployment of sql_executor_brick.zip file to the Goddata platform: 

1. Deploy the ZIP to the gooddata platform by Data Admin Console [link] (https://secure.gooddata.com/admin/disc/)
2. Create a schedule and fill in mandatory parameters (specified in info.json file).
3. Execute the schedule


###  Schedule parameters

 * **ads_server (optional)** - (default -> secure.gooddata.com") gooddata server url
 * **ads_instance_id** - ADS instance ID
 * **ads_username** - ADS username
 * **ads_password** - ADS password
 * **folder** - folder on S3 which contains SQL scripts. Must be specified in format s3://bucket/any/custom/folder/
 * **access_key** - access key to S3
 * **secret_key** - secret key to S3 
 * **number_of_threads** **(optional)** (default -> 4) - number of SQL commands executed in parallel


## SQL script files naming convention


Script name must follow the mask: \[Phase#\]_\[ScriptName\].\[Extension\] (e.g. "10_user.sql")

 * Phase# - Phase(group) number (eg. "10")  .
 * ScriptName - Self explanatory (eg. "user").
 * Extension - .sql or .psql or .isql

Supported extensions:

 * "sql" - simple SQL scripts
 * "psql" - script used for reading of SQL executor parameters from ADS
 * "isql" - script iteration through predefined parameters collection

### SQL scripts

One script file can contain more SQL commands, in that case commands are processed one after the other in one thread. SQL comments are supported.
 
### PSQL scripts

PSQL scripts are used to fill SQL executor parameters from ADS. 
Each script has to start with **/* DEFINE('param_name') */** construction at the first line. 
Subsequent command must contain SQL select statement which returns result set. Schedule parameters are supported. Detailed info can be found in the next section.

### ISQL scripts

ISQL scripts are used for iteration over set of SQL commands. 
Each script has to start with **/*ITERATION('param_name')*/** construction at the first line. 
Subsequent command(s) is (are) executed for each set of param_name values. Schedule parameters are supported. Detailed info can be found in the next section.


## Parameters

### Schedule parameter

Parameters from schedule settings, which are not standard SQL executor "Schedule parameters" mentioned above, can be used as parameters in SQL scripts. The algorithm is looking for construction ${param_name} and replaces this section by the value of the parameter.

#### Example
    
    Schedule parameter
    customer_type = GOLD
    
    SQL Script
    SELECT Id,Name FROM Customers WHERE customer_type = '#{customer_type}';
    
    Executed script
    SELECT Id,Name FROM Customers WHERE customer_type = 'GOLD'

### Key/Value parameter read from ADS

Inside PSQL script files you can define key/value parameters loaded from ADS. 

The first line of the PSQL script has to start with the parameter definition: **/* DEFINE('param_name') */**. Following command in PSQL file has to be SQL select statement returning two columns named "key" and "value". In all script files executed after the PSQL script, you can reference the parameter by the ${param_name['key']} construction.

!Please note, if your select statement returns two lines with the same key, only the last line is used. 

#### Example

Source table - Settings

| Id | Setting |
|----------|----------|
| type | GOLD |
| environment | Linux |
| browser | Chrome |
    
    PSQL Script
    /* DEFINE('settings') */
    SELECT Id as "Key",Setting as "Value" from Settings;

    SQL Script (executed after PSQL script)
    DELETE FROM Customers WHERE type = '${settings['type']}' and browser = '${settings['browser']}'; 
    
    Executed script
    DELETE FROM Customers WHERE type = 'GOLD' and browser = 'Chrome';
    
### Iteration parameters read from ADS

In the PSQL script file, you can define script which returns the list through which you can iterate by subsequent SQL. This script must returns key column and any number of columns which are used as parameters in isql script files. 

Please note, if your select statement returns two lines with the same key, only the last line will be used.

#### Example

Source table - custom_partitions

| table_name | partition |
|----------|----------|
| account | 55 |
| account | 60 |
| opportunity | 55 |
| opportunity | 60 |
| product | 55 |
| product | 60 |


    PSQL Script
    
    /* DEFINE('partitions') */
    SELECT row_number() over (order by table_name) as "key",table_name as table_name,partiotion as partition from custom_partitions;

    ISQL Script
    /* ITERATION('partitions') /
    SELECT DROP_PARTITION('${table_name}', ${partition});

    Executed scripts
    SELECT DROP_PARTITION('account', 55);
    
    SELECT DROP_PARTITION('account', 60);
    
    SELECT DROP_PARTITION('opportunity', 55);
    
    SELECT DROP_PARTITION('opportunity', 60);
    
    SELECT DROP_PARTITION('product', 55);
    
    SELECT DROP_PARTITION('product', 60);

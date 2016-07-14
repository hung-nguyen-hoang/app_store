CSV Downloader Brick
==================
This brick can be used for downloading CSV files from various sources (at the moment S3 source is supported).

## Description

This part of documentation is covering only the CSV downloader. The overall information about the connectors structure can be found in connectors metadata gem documentation [link](https://github.com/gooddata/gooddata_connectors_metadata/tree/bds_implementation).

The current version of downloader support data download froM S3 and from SFTP.

## Limits

The limits of the CSV downloader are mostly determined by the limitations of the GoodData Ruby Workers.

### File size
 
The the biggest file size, which can be processed by the CSV downloader is around 2GB (the limit is applicable only if number_of_threads set to 1. With different settings the max file size is number times smaller), but I am strongly recommending to have the files of size around 100MB. The processing of small files is much faster.


## Deployment

The deployment on Ruby Executor infrastructure can be done manually or by the Goodot tool.

### Manual deployment

1. Pack the app store folder apps/csv_downloader_brick. The zip should contain only files, not the directory itself.
2. Deploy the ZIP on the gooddata platform by Data Admin Console [link] (https://secure.gooddata.com/admin/disc/)
3. Create the schedule and put mandatory configuration options to schedule parameters. Mandatory parameters are specified in info.json file.
4. Run the schedule

### Gooddot deployment

The deployment configuration for Gooddot could look like this:

    {
      "processes" : [
        {
            "deployment_type": "app_store",
            "app_id": "csv_downloader_brick",
            "process_type": "ruby",
            "name" : "CSV Connector - Goodot",
            "schedules" : [
                {
                  "name" : "Batch A",
                  "when" : "0 2 2 2 *",
                  "params": {
                  "{{bds_params}}": null,
                  "ID":"csv_downloader_2"
                  },
                  "hidden_params" : {
                    "{{bds_secret_params}}" : null,
                    "csv|options|secret_key":"{{customer_secret}}"
                  }
                }

            ]
        }
      ],
     "params": {
        "bds_params":{
            "bds_bucket": "bds_bucket",
            "bds_folder":"bds_folder",
            "bds_access_key":"access_key",
            "account_id":"AccountName",
            "token":"Token"
        },
        "bds_secret_params":{
            "bds_secret_key":"bds_secret_key"
        },
        "customer_secret":"customer_secret"
      }
    }

After running the Gooddot sync command, you only need to run the schedule on platform.

###  Additional schedule parameters

 * **server_side_encryption** (true/false) (default -> false) - this will enable you usage of the BDS with server side encryption enabled. 

## Data source

The data source need to be accessible by the credentials provided to CSV downloader. The data source should contain the following files:

 * Feed file
 * Manifest files
 * Data files

### Feed file

The feed file is providing information about the structure of the provided data files.

The structure of the file should look like this:

 * **file** - name of the entity, to which this row is connected
 * **version** - the version of file to which the row is connected (this is used for further changes of uploaded CSV files). For example that customer wants to add one column to the source CSV file. We know that in version 1.0 the column was not there and in version 1.1 the columns was there. This will allow us to reprocess the historical data without any changes to FEED file
 * **field** - name of the field (column in source file)
 * **type** - the data type of the field (the supported types are stated at the end of this section)
 * **order** - the order in which the fields are ordered in source files

### Supported types (case insensitive)

 * string(X) - varchar(X) or string(X) or string-X,
 * string(255) - string or varchar
 * integer - integer or bigint
 * decimal(X,Y) - decimal(X,Y) or decimal-X-Y or numeric-X-Y
 * decimal(16,10) - numeric
 * boolean - boolean
 * Date without time - date 
 * Date with time - datetime or timestamp without time zone
 * Time without date - time 
 

All other types are threaded as string-255

#### Example:

    file|version|field|type|order
    Account |1.0|ID|integer|0
    Account|1.0|Name|string-255|1
    Account|1.0|Attribute1|string-255|2
    Account|1.0|Attrubute2|string-255|3
    Account|1.1|Name|string-255|1
    Account|1.1|Attribute1|string-255|2
    Account|1.1|Attrubute2|string-255|3
    Account|1.1|Attribute3|string-255|4
    User|1.0|ID|integer|1
    User|1.0|Name|string-255|2
    User|1.0|Attribute1|string-255|3
    Facts|1.0|ID|integer|1
    Facts|1.0|account_id|integer|2
    Facts|1.0|user_id|integer|3
    Facts|1.0|fact1|decimal-20-5|4
    Facts|1.2|ID|integer|1
    Facts|1.2|account_id|integer|2
    Facts|1.2|user_id|integer|3
    Facts|1.2|fact1|decimal-20-5|4
    Facts|1.2|fact2|decimal-20-5|5

### Manifest files

The second file is manifest file. This file will bind the uploaded files to one batch and this batch of files will be processed as one. The manifest file need to follow specific name convention:
manifest-{batch_identification}_{sequence}.{time}

 * **batch_identification** - string which identifies batch. It is possible to group uploaded files to multiple batches (for example when each file is loaded in different time window). Batch identification can be for example batchA and batchB.
 * **sequence** (optional) - sequence number of manifest files. The files uploaded to the source need to follow the sequence. In case that sequence is broken, the batch will not be processed and connector will wait till the missing sequence is loaded.
 * **time** - time of manifest creation in format YYYYMMDDHHMMSS (for example 20150217104924). The format can be easily change if needed.

The name of the manifest can look like this: **manifest-batchB_1.20150217104924.csv**

The sequence number is stored with the downloaded data file and can be used to fill the computed field in the integrator settings.

The structure of the file should look like this:

 * **file_url** - full path to desired file uploaded on storage
 * **target_ads** - **OBSOLETE**
 * **timestamp** - unix timestamp representing time when file was uploaded on storage
 * **feed** - name of entity, to which the file is connected
 * **feed_version** - the version in FEED file to which the uploaded file is connected ( **only one version of entity can be present in manifest file** - you cannot have Account v1.0 and Account v2.0 in one manifest)
 * **num_rows** **(optional)** - number of rows in uploaded file
 * **md5** - MD5 checksum of uploaded file. You can put "unknown" value to this columns and then the MD5 check will be ignored. 
 * **export_type** **(optional)** - possible values (inc/full). Default is inc. It marks if the file in manifest is full or increment. It changes how the file is integrated to database. 


You can add any additional fields to the manifest. Value of the field will be stored and connected to downloaded file and then can be further used to fill the computed fields in the integrator settings.

#### Example:

    file_url|target_ads|timestamp|feed|feed_version|num_rows|md5|export_type
    s3://bucket/folder/account.20111231235959.txt.gz||1325404799|Account|1.0|2|87c6054999cf18ba69568993357e09f9|full
    s3://bucket/folder/user.20111231235959.txt.gz||1325404799|User|1.0|1|8a4c647cd56e77cb37cf0a5566157dc9|full
    s3://bucket/folder/facts.1.20111231235959.txt.gz||1325404799|Facts|1.2|15444|5d0a290ca7fc8d4dc7dd9cdd0dd15f96|inc
    s3://bucket/folder/facts.2.20111231235959.txt.gz||1325404799|Facts|1.2|52755|ba63d9912e49fa4f4b2e0797d3fcfa41|inc

### Data files

The data files will contain data, which the user want to download. The downloader is accepting pure CSV or GZIPed CSV files. Customer need to specify the format of the CSV file in corresponding section of the CSV downloader. How the configuration should look like can be found in configuration section of this document.

## Configuration

This section is containing information about the CSV downloader section of the configuration.json file. It is important to know that CSV downloader is processing data in batches. One manifest file equals one batch. If you want to set up the ADS integrator processing data downloader by CSV connector, you need to switch it to the batch mode. The name of the batch is ID of the connector.

The switching between S3 and SFTP is done by type parameter (s3,sftp)

The structure of the configuration file:
 
 * **folder** - name of the folder on the data source. In this folder the manifests files need to be present. It is possible to have more tree like structure. The tool will be looking for manifest in whole path after this path.
 * **data_structure_info** - the full path to the FEED file
 * **manifest** - definition of the manifest file ( more info below )
 * **manifest_process_type** (move/history) - if set to move, the manifest file will be moved to processed folder. If set to history, the manifest will stay.
 * **number_of_manifest_in_one_run** - maximum number of manifests which is processed in one run. Default value is 1
 * **delete_data_after_processing** (true/false) - if set to TRUE, the data will be delete from the source, after processing. Default FALSE.
 * **number_of_threads** (1) - this parameter will set how many threads will be used when copying data from source location to the BDS 
 * **ignore_check_sum** (true/false) - this options set to true will ignore the MD5 checksum when downloading the file 
 * **file_structure** - this section of the configuration is dedicated to structure of the file. This hints are need for CSV parsing when loading it to ADS. More information about each of the option can be found in Vertica documentation [link](http://my.vertica.com/docs/6.1.x/HTML/index.htm#1668.htm).
    * **skip_rows** (optional) - number of skipped columns in CSV (used mainly to remove header from CSV file)
    * **column_separator** (optional) - the character which is separating fields in CSV
    * **escape_as** (optional) - specifies the the escaping character
    * **file_format** (optional) - specify format of the file. Empty is pure CSV. In case of GZIP file use GZIP option.
    * **db_parser** (optional) - specify the type of parser used by ADS. Empty is default parser. In case you want to use GDC Parser use gdc option.
    * **enclosed_by** (optional) - specifies the enclosing character
    * **null_value** (optional) - specifies the null value character
    
    
The S3 specific configuration:
 
 * **bucket** - name of the S3 bucket
 * **access_key** - access key to S3 bucket
 * **secret_key** - secret key to S3 bucket (this parameter should be not saved in configuration.json file but provided to execution by Secure Parameter. How to do it can be found in metadata gem documentation)
 * **use_link_file** (true/false) - if set to TRUE, the link file functionality will be enabled. More info about this functionality is at the end of this document.
 * **server_side_encryption** (true/false) - this will enable you to use the connector with the S3 where the server side encryption is enabled 


The SFTP specific configuration:

 * **username** - username used to connect to SFTP
 * **auth_mode** - (password/cert) - which mode is used to authenticate to server
 * **host** - host name of the SFTP server
 * **port** - (22) port on which the SFTP is running
 * **password** - (auth_mode -> password) used for authentication to SFTP server
 * **cert_path** - (auth_mode -> cert) path to the certificate, which should be used to connect to SFTP server (the certificate need to be deployed in the CSV downloader package)
 * **cert_passphrase** - (auth_mode -> cert) passphrase used to decrypt the certificate

The SFTP has some of the parameters set to constant value (the value cannot be changed)

 * ignore_check_sum -> true
 * number_of_threads -> 1
 
### Explanation of manifest process type parameter
 
 The CSV downloader can work in two mode. The move and history.
  
#### Move mode
  
  The file is automatically moved to the processed directory. What is important here to say is, that the timestamp of the manifest is used only to decided the order of processing, but it is not checking if the timestamp which you have provide is after or before the files processed in previous run.  

#### History mode
 
 The CSV downloader is checking what manifest were processed previously and determing if there is new manifest in the current location. This aproach is good when you don't have write access to the source location, but it is generally slower, because the CSV downloader need to list all manifest and already processed batches. This mode is also not checking if newly upload manifest timestamp is after last downloader file. The downloader will simply process manifest if it was not processed yet.
  

### Manifest option

The manifest option specify how the information about sequence number and time should be parsed from name of the file.

For example the definition for this manifest name: **manifest-batchB_1.20150217104924.csv** will look like this: **manifest-batchB_{sequence}.{time(%Y%m%d%H%M%S)}**

The time format can be changed as desired. The documentation of possible tags can be found in documentation of the strftime function [link](http://ruby-doc.org/core-2.2.0/Time.html#method-i-strftime).

### Example

    "csv": {
            "type": "s3",
            "options": {
                "bucket": "gdc-ms-cust",
                "folder": "some_bds_folder/structure/",
                "data_structure_info": "some_bds_folder/setting/FEED",
                "access_key": "key",
                "secret_key": "secret",
                "manifest": "manifest-batchA_{sequence}.{time(%Y%m%d%H%M%S)}",
                "files_structure": {
                    "skip_rows": "1",
                    "column_separator": ",",
                    "escape_as": "\"",
                    "file_format": "gzip"
                }
            }
        }

### Linked files

In default setting the CSV downloader is downloading the data from the source and saving them to GoodData BDS. In case of bigger files this process can be quite time consuming and not wanted in all occasions. 

If you can guarantee that file in source will not be deleted, you can use the link file functionality. In this case the CSV downloader will not download the data from source, but it will create LINK file on BDS with links to the source file. 

Then after you add additional settings to integrator, the files will be downloaded from source location directly by integrator.

### One entity in multiple versions

The CSV Downloader is now supporting one entity in multiple version. The downloader will not only use latest version from feed file, but it will store and use all historical version. If you then use the old version in the manifest file, the downloaded will not create the new matadata file, but it will use the metadata file for this specific version. 
This can be used in case that the customer have one entity, but export for this entities can slightly differ. 







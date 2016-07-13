Twitter Downloader Brick
==================
This brick can be used to download data from twitter accounts. Currently only entities are account and tweet.

## Description

This part of documentation is covering only the Twitter downloader. The overall information about the connectors structure can be found in connectors metadata gem documentation [link](https://github.com/gooddata/gooddata_connectors_metadata/tree/bds_implementation).

## Deployment

The deployment on Ruby Executor infrastructure can be done manually.

### Manual deployment

1. Pack the app store folder apps/twitter_downloader_brick. The zip should contain only files, not the directory itself.
2. Deploy the ZIP on the gooddata platform by Data Admin Console [link] (https://secure.gooddata.com/admin/disc/)
3. Create the schedule and put mandatory configuration options to schedule parameters. Mandatory parameters are specified in info.json file.
4. Run the schedule

## How it works

The Twitter downloader scan accounts you specify in configuration. After logging of necessary details regarding account, it starts to gather information about tweets created from this account.
All the information regarding user and tweets are gathered through getters of objects.

## Configuration

This section is containing information about the Twitter downloader section of the configuration.json file.

## Entity configuration

There are some special configurations possible for the Twitter downloader on entity level. The example entity configuration can look like this:

### Example
 
    "account": {
      "global": {
          "collection": "account",
          "prefix": "account",
          "custom": {
              "hub": [
                  "id"
                ]
            },
          fields:[
            {
              "id": "screen_name",
              "name": "screen_name",
              "type": "string-32",
              "object":"user"
            },
            {
              "id": "date",
              "name": "date",
              "type": "string-32",
              "command": "now"
            }
          ]
      }
    }

## Twitter configuration

Configuration consists of 4 parts.

entities - part you specify entities you want to download.
         - fields are differentiated by object/command attribute
            -object attribute is using 'id' attribute of object 'user'
            -command is custom field
                - possible values
                    -now => returns current date YYYY/MM/DD
                    -now+n => returns future or past date depending on n
                    -'xyz' => returns 'xyz'
credentials - part you specify twitter credentials to twitter account used to scan other twitter accounts.
twitter_accounts - accounts you want to scan and tweet to download considering date options

### Example

    "twitter": {
            "entities": [
                "account",
                "tweet"
            ],
            "credentials": {
                "consumer_key": "",
                "consumer_secret": "",
                "access_token": "",
                "access_token_secret": ""
            },
            "twitter_accounts_file": "twitter_accounts.csv",
            "twitter_accounts": [
                {
                    "id": "JeremyClarkson",
                    "date_from": "2016/07/01"
                },
                {
                    "id": "ClashofClans",
                    "date_from": "2016/07/01"
                },
                {
                    "id": "RichardHammond",
                    "date_from": "2016/07/01"
                }
            ]
        }

 

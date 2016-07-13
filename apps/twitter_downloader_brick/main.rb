# encoding: utf-8

require 'fileutils'

debug_install = true if !$SCRIPT_PARAMS.nil? and $SCRIPT_PARAMS.include?("DEBUG_INSTALL")

$SCRIPT_PARAMS.each_pair do |key,value|
  STDERR.puts "#{key}:#{value}"
end

postfix = debug_install ? "2>&1": "1>/dev/null"

package = 'https://gdc-ms-ruby-packages.s3.amazonaws.com/twitter_downloader_brick/v0.0.1.zip'
system("curl -LOk --retry 3 #{package} #{postfix}")

local_package = package.split('/').last
system("unzip -o #{local_package} #{postfix}")

#Create output folder
require 'fileutils'
FileUtils.mkdir_p('output')

# Bundler hack
require 'bundler/cli'
Bundler::CLI.new.invoke(:install, [],:path => "gems",:jobs => 4,:deployment => true)

# Required gems
require 'bundler/setup'
require 'gooddata'
require 'gooddata_connectors_metadata'
require 'gooddata_connectors_downloader_twitter'

# Require executive brick
require_relative 'execute_brick'

FileUtils.mkdir_p('tmp')

include GoodData::Bricks

# Prepare stack
stack = [
  LoggerMiddleware,
  BenchMiddleware,
  GoodData::Connectors::Metadata::MetadataMiddleware,
  GoodData::Connectors::DownloaderTwitter::TwitterDownloaderMiddleWare,
  ExecuteBrick
]

# Create pipeline
p = GoodData::Bricks::Pipeline.prepare(stack)

# Default script params
$SCRIPT_PARAMS = {} if $SCRIPT_PARAMS.nil?


$SCRIPT_PARAMS['GDC_LOGGER'] = Logger.new(STDOUT)

# Execute pipeline
p.call($SCRIPT_PARAMS)

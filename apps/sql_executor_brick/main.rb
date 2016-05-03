# encoding: utf-8

puts "RUBY - SQL EXECUTOR BRICK"

# Required gems
require 'bundler/setup'
# Require executive brick
require_relative 'execute_brick'
require_relative 'lib/s3_wrapper'
require_relative 'lib/ads_wrapper'

FileUtils.mkdir_p('tmp')

# Default script params
$SCRIPT_PARAMS = {} if $SCRIPT_PARAMS.nil?

object = SqlExecutor::ExecuteBrick.new
object.call($SCRIPT_PARAMS)


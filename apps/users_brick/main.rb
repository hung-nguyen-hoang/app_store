# encoding: utf-8
params = $SCRIPT_PARAMS.to_hash

require 'bundler/cli'
verbose_bundler = params['VERBOSE_BUNDLER'] == 'true' ? true : false
bundler_opts = verbose_bundler ? { verbose: true } : { quiet: true }
bundler_default_opts = { path: 'gems', :retry => 3, :jobs => 4 }

Bundler::CLI.new.invoke(:install, [], bundler_default_opts.merge(bundler_opts))
require 'bundler/setup'
require 'gooddata'

require_relative 'users_brick'
require_relative 'vendor/dwh_middleware'

include GoodData::Bricks

p = GoodData::Bricks::Pipeline.prepare([
  DecodeParamsMiddleware,
  LoggerMiddleware,
  BenchMiddleware,
  GoodDataMiddleware,
  AWSMiddleware,
  WarehouseMiddleware,
  FsProjectUploadMiddleware.new(:destination => :staging),
  UsersBrick])

p.call(params)

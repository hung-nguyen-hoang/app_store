# encoding: UTF-8

require 'gooddata'
require 'gooddata_datawarehouse'

module GoodData
  module Bricks
    class WarehouseMiddleware < Bricks::Middleware
      def call(params)
        if params.key?('ads_client')
          puts "Setting up ADS connection to #{params['ads_client']['ads_id']}"
          fail "ADS middleware needs username either as part of ads_client spec or as a global 'GDC_USERNAME' parameter" unless params['ads_client']['username'] || params['GDC_USERNAME']
          fail "ADS middleware needs password either as part of ads_client spec or as a global 'GDC_PASSWORD' parameter" unless params['ads_client']['password'] || params['GDC_PASSWORD']
          
          ads = GoodData::Datawarehouse.new(params['ads_client']['username'] || params['GDC_USERNAME'], params['ads_client']['password'] || params['GDC_PASSWORD'], params['ads_client']['ads_id'])
          @app.call(params.merge('ads_client' => ads))
        else
          @app.call(params)
        end
      end
    end
  end
end

# encoding: utf-8

module GoodData::Bricks
  class ExecuteBrick < GoodData::Bricks::Brick
    def call(params)
      logger = params['GDC_LOGGER']
      metadata = params["metadata_wrapper"]
      sprinklr_downloader = params["sprinklr_downloader_wrapper"]
      raise Exception, "You need to specify ID of the downloader" if !params.include?("ID")
      sprinklr_downloader.inject_logging_entity(params["ID"])
      metadata.set_source_context(params["ID"],{},sprinklr_downloader)
      sprinklr_downloader.connect
      entities =  metadata.get_downloader_entities_ids
      begin
        entities.each do |entity|
          sprinklr_downloader.download_data(entity)
        end
      rescue => e
        pp e.backtrace
        raise Exception, e.message
      ensure
        sprinklr_downloader.finish
      end
    end
  end
end

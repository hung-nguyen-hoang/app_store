require 's3'
require 'pp'
module SqlExecutor

  class S3Wrapper

    def self.tmp_dir
      'tmp'
    end

    def initialize(opts)
      @service = S3::Service.new(:access_key_id => opts['access_key'],:secret_access_key => opts['secret_key'],:use_ssl => true)
    end


    def list(folder)
      # Folder is provider in format "s3://bucket/folder/folder/folder"
      bucket = folder.match(/s3:\/\/([^\/]*)\/(.*)/)[1]
      s3_folder = folder.match(/s3:\/\/([^\/]*)\/(.*)/)[2]
      bucket = @service.bucket(bucket)
      bucket.objects.find_all({
                          :prefix => s3_folder,
                          :marker => s3_folder,
                          :delimiter => '/'
                         })
    end


    def download(file_name,remote_object)
      File.open(File.join(S3Wrapper.tmp_dir,file_name),'w') do |file|
        file.write(remote_object.content)
      end
    end




  end


end
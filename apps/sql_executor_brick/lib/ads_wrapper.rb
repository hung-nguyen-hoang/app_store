module SqlExecutor
  class ADSWrapper

      class << self

        Jdbc::DSS.load_driver
        Java.com.gooddata.dss.jdbc.driver.DssDriver

        def set_up(instance_id,username,password,server = nil)
          @instance_id = instance_id
          @username = username
          @password = password
          @status = 'ready'
          @server = server || 'secure.gooddata.com'
        end

        def connect
          dss_jdbc_url = "jdbc:dss://#{@server}/gdc/dss/instances/#{@instance_id}"
          $log.info "Connecting to #{dss_jdbc_url}"
          @db = Sequel.connect(dss_jdbc_url, :username=> @username, :password=> @password,:pool_timeout=>240,:max_connections=>15)
          @status = 'connected'
          @connection_start = Time.now
        end

        def disconnect
          @status = 'ready'
          @db.disconnect
        end


        def db
          if (@status != 'connected')
            connect
          end
          #Lets try to refresh connection
          if (Time.now - @connection_start > 2*60)
            $log.info 'Refreshing connection'
            disconnect
            connect
          end
          @db
        end

        def fetch(sql)
          if (@status != 'connected')
            connect
          end
          #Lets try to refresh connection
          if (Time.now - @connection_start > 2*60)
            $log.info 'Refreshing connection'
            disconnect
            connect
          end
          @db.fetch(sql)
        end

      end

  end
end


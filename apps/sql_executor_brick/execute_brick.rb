# encoding: utf-8

require 'jdbc/dss'
require 'gooddata/dss/sequel'
require 'peach'
require 'logger'
require 'benchmark'
require 'thread'

module SqlExecutor
  class ExecuteBrick

      Jdbc::DSS.load_driver
      Java.com.gooddata.dss.jdbc.driver.DssDriver

      CORE_PARAMS = ['ads_server','ads_instance_id','ads_username','ads_password','number_of_threads','folder']

      POSTFIXES = ['sql','psql','isql']

      def call(params)
        puts "Inside ExecuteBrick"
        $log = Logger.new(STDOUT)
        $log.formatter = proc do |severity, datetime, progname, msg|
          "#{msg}\n"
        end


        @server = params['ads_server'] || 'secure.gooddata.com'
        @instance_id = params['ads_instance_id']
        @username  = params['ads_username']
        @password = params['ads_password']

        @folder = params['folder']
        @number_of_threads = Integer(params['number_of_threads'] || '4')

        @parameters = {}

        # Prepare list of parameters to replace in the SQL queries
        @list_of_non_core_parameters = {}
        params.each_pair do |k,v|
          if !CORE_PARAMS.include?(k)
            @list_of_non_core_parameters[k] = v
          end
        end

        s3 = S3Wrapper.new(params)


        object_list = s3.list(@folder)
        file_list = []

        object_list.each do |value|
          filename =  value.url.split("/").last
          if (POSTFIXES.include?(filename.split('.').last))
            s3.download(filename,value)
            file_list << filename
          end
        end

        execution_list = file_list.group_by do |file_name|
          order_number = file_name.split("_").first
          begin
            Integer(order_number,10)
          rescue
            'invalid'
          end
        end

        fail "Some of the files do not match expected naming structure (#{execution_list['invalid'].join(',')})" if (execution_list.include?('invalid'))

        ADSWrapper.set_up(@instance_id,@username,@password,@server)

        @semaphore = Mutex.new

        execution_list = Hash[execution_list.sort_by{|k,v| k}]
        log_plan(execution_list)
        execution_list.each_pair do |key,values|
          values.sort_by!{|v| v.split("_")[1..-1].join("_") }

          $log.info "Executing Group #{key}"
          queue = Queue.new
          values.each { |child_task| queue <<  child_task }
          threads = []
          duration = Benchmark.measure do
            @number_of_threads.times do
              threads << Thread.new do |i|
                # loop until there are no more things to do
                until queue.empty?
                  # pop with the non-blocking flag set, this raises
                  # an exception if the queue is empty, in which case
                  # work_unit will be set to nil
                  work_unit = queue.shift(true) rescue nil
                  if work_unit
                    do_work(work_unit)
                  end
                end
                # when there is no more work, the thread will stop
              end
            end
            threads.each { |t| t.join }
          end
          $log.info "Group #{key} took: " + duration.real.to_s
        end
      end


      def do_work(element)
        content = File.read(File.join(SqlExecutor::S3Wrapper.tmp_dir,element))
        if (element.split('.').last == 'sql')
          execute_sql(element,content)
        elsif (element.split('.').last == 'psql')
          execute_psql(element,content)
        elsif (element.split('.').last == 'isql')
          execute_isql(element,content)
        else
          $log.info "Something Wong"
        end
      end



      def execute_sql(element,content)
        $log.info "Executing script: #{element}"
        content = replace_parameters(content,@list_of_non_core_parameters)
        content = replace_key_value_parameters(content)
        $log.info "SQL command: \n#{content}"
        begin
          $log.info "Command #{element} took: " + Benchmark.measure{ADSWrapper.db.run(content)}.real.to_s
        rescue => e
          raise Exception, "The execution of file #{element} has failed. Message #{e.message}"
        end
      end

      def execute_psql(element,content)
        temp = {}
        # First line of the script should be parameter
        first_line = content.lines.first
        match = first_line.match(/[^(]*'(?<param>[^']*)'/)
        fail "The parameter is defined in incorrect way - correct way /* DEFINE('PARAM_NAME') */" if match.nil?
        param_name = match[:param]

        # Lets remove first line and leave there only the SQL
        content = remove_first_line(content)
        $log.info "Executing script: #{element}"
        content = replace_parameters(content,@list_of_non_core_parameters)
        content = replace_key_value_parameters(content)
        $log.info "SQL command: \n#{content}"
        $log.info "Parameters loaded to collection #{param_name} are:"

        benchmark = Benchmark.measure do
          ADSWrapper.db.fetch(content) do |row|
            hash = {}
            row.keys.each do |key|
              hash[key.to_s] = row[key].to_s
            end
            temp[row[:key].to_s] = hash
            $log.info " Key: #{row[:key]} Values: \n #{hash.map{|key,value| "   #{key}=#{value}\n"}.join}"
          end
        end

        @semaphore.synchronize do
          @parameters[param_name] = temp
        end
        $log.info "Command #{element} took: #{benchmark.real.to_s}"
      end

    def execute_isql(element,content)
      # First line of the script should be parameter
      first_line = content.lines.first
      match = first_line.match(/^[^\(]*\('(?<param>[^']*)'(\)|,(?<thread>\d))/)
      fail "The parameter is defined in incorrect way - correct way /* ITERATOR('PARAM_NAME',5) */" if match.nil?
      param_name = match[:param]
      threads = Integer(match[:thread] || "1")

      # Lets remove first line and leave there only the SQL
      content = remove_first_line(content)
      $log.info "Executing script: #{element}"

      fail "The parameter is not defined #{param_name}" if !@parameters.include?(param_name)
      parameter_values = @parameters[param_name]

      parameter_values.peach(threads) do |key,value_hash|
        begin
          sql = content.dup
          sql = replace_parameters(sql,value_hash)
          $log.info "SQL command: \n#{sql}"
          $log.info "Command #{element} took: " + Benchmark.measure{ADSWrapper.db.run(sql)}.real.to_s
        rescue => e
          raise Exception, "The execution of file #{element} has failed. Message #{e.message}"
        end
      end
    end


    def remove_first_line(text)
      string_without_first_line = ""
      text.lines.each_with_index do |line,index|
        if (index > 0)
          string_without_first_line += line
        end
      end
      string_without_first_line
    end

    def replace_parameters(sql,params)
      params.each_pair do |key,value|
        sql.gsub!("${#{key}}",value)
      end
      sql
    end

    def replace_key_value_parameters(sql)
      match_data = sql.scan(/\${[^}]*}/)
      match_data.each do |param_string|
        # We are looking for format ${param['key']}
        value = param_string.match(/\${(?<name>[^\[]*)\['(?<key>[^']*)']}/)
        fail "Invalid format of the parameter - looking for format ${param['key']} - have: #{param_string}" if value.nil?
        fail "Collection #{value[:name]} is not present in parameter list" if !@parameters.include?(value[:name])
        collection = @parameters[value[:name]]
        fail "Collection #{value[:name]} don't have key #{value[:key]}" if !collection.include?(value[:key])
        fail "Collection #{value[:name]} don't have value named 'value'" if !collection[value[:key]].include?('value')
        sql.gsub!("${#{value[:name]}['#{value[:key]}']}",collection[value[:key]]['value'].to_s)
      end
      sql
    end



    def log_plan(execution_list)
      $log.info 'Execution plan:'
      execution_list.each_pair do |key,value|
        $log.info "Group: #{key}"
        value.each do |file|
          $log.info "   File: #{file}"
        end
      end
    end
  end
end


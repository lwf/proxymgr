module ProxyMgr
  class Haproxy
    class Process
      require 'proxymgr/process_manager'

      include Logging
      include Callbacks

      attr_reader :exit_code

      def initialize(path, config_file)
        @path        = path
        @config_file = config_file

        @mutex       = Mutex.new

        callbacks :on_stop
      end

      def start
        restart
      end

      def restart
        @mutex.synchronize do
          if @process
            run(@process.pid)
          else
            run
          end
        end
      end

      [:wait, :stop].each do |sym|
        define_method(sym) { |*args, &blk| @process.send(sym, *args, &blk) }
      end

      private

      def run(pid = nil)
        args = ['-f', @config_file, '-db']
        if pid
          args << '-sf'
          args << pid.to_s
        end

        @process = ProcessManager.new(@path, args)
        [:on_stdout, :on_stderr].each do |cb|
          @process.send(cb, &method(:parse_haproxy_log))
        end
        @process.on_stop(&method(:handle_stop))
        @process.start
      end

      def handle_stop(status)
        @exit_code = status
        call(:on_stop, status)
      end

      def parse_haproxy_log(line)
        matches = line.scan(/^\[(.*)\] (.*)/)[0]
        if matches
          haproxy_level, msg = matches
          level = haproxy_level == 'WARNING' ? :warn : :info
          logger.send(level, msg)
        else
          logger.info(line)
        end
      end
    end
  end
end

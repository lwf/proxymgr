module ProxyMgr
  class Haproxy
    class Process
      require 'state_machine'

      include Logging

      state_machine :state, :initial => :stopped do
        event :start do
          transition [:stopped, :exited] => :running, :if => :run
        end

        event :exited do
          transition :running => :exited
        end

        event :stop do
          transition :running => :shutdown
        end

        after_transition :running => :shutdown do |process|
          process.stopping
          process.process_manager.stop
        end

        event :replace do
          transition :running => :stopping
        end

        event :stopping do
          transition :shutdown => :stopping
        end

        event :stopped do
          transition :stopping => :stopped
        end

        state :running do
          def handle_stop(status)
            @exit_code = status
            if abnormal_exit?
              exited
            else
              stopped
            end
            @callback.call status
          end
        end

        state :stopping do
          def handle_stop(status)
            @exit_code = status
            stopped
          end
        end
      end

      attr_reader :exit_code, :process_manager

      def initialize(path, config_file, old_pid = nil, &callback)
        @path        = path
        @config_file = config_file
        @old_pid     = old_pid
        @callback    = callback

        super()
      end

      [:pid, :wait].each do |sym|
        define_method(sym) { @process_manager.send(sym) }
      end

      private

      def abnormal_exit?
        @exit_code && @exit_code > 0
      end

      def run
        args = ['-f', @config_file, '-db']
        if @old_pid
          args << '-sf'
          args << @old_pid.to_s
        end

        @process_manager = ProcessManager.new(@path, args)
        [:on_stdout, :on_stderr].each do |cb|
          @process_manager.send(cb, &method(:parse_haproxy_log))
        end
        @process_manager.on_stop(&method(:handle_stop))
        @process_manager.start
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

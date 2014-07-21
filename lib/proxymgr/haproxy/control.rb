module ProxyMgr
  class Haproxy
    class Control
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

      def restart(fds = [])
        @mutex.synchronize do
          if @process
            run(@process.pid, fds)
          else
            run(nil, fds)
          end
        end
      end

      [:wait, :stop, :exited?].each do |sym|
        define_method(sym) { |*args, &blk| @process.send(sym, *args, &blk) }
      end

      private

      def run(pid = nil, fds = [])
        @process.replace if @process
        @process = Process.new(@path, @config_file, fds, pid) do |status|
          call(:on_stop, status)
        end
        @process.start
      end
    end
  end
end

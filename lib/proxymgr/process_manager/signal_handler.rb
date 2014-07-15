module ProxyMgr
  class ProcessManager
    class SignalHandler
      include Logging

      def initialize
        @pids = {}

        start
      end

      def register(pid, &blk)
        @pids[pid] = blk
      end

      private

      def start
        Signal.trap(:CHLD) do
          handled = {}
          begin
            loop do
              pid, status = Process.waitpid2(-1, Process::WNOHANG)
              break unless pid
              handled[pid] = result(status)
            end
          rescue Errno::ECHILD
          end
          handled.each do |pid, result|
            handle(pid, result)
          end
        end
      end

      def handle(pid, status = nil)
        @pids.delete(pid).call(status) if @pids[pid]
      end

      def result(status)
        status && (status.exitstatus || status.termsig)
      end
    end
  end
end

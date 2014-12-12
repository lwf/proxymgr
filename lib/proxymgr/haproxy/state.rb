module ProxyMgr
  class Haproxy
    class State
      require 'tempfile'
      require 'pathname'
      require 'erb'

      include Logging, Configurable

      attr_accessor :socket_path

      def initialize(process, socket_manager)
        @process         = process
        @socket_manager  = socket_manager

        @sleep_interval  = 5

        @file_descriptors = {}
        @backends         = {}
        @config_template  = ERB.new(File.read(File.join(ProxyMgr.template_dir, 'haproxy.cfg.erb')))
        @mutex            = Mutex.new
        @cv               = ConditionVariable.new

        config_attr :config_file, :global_config, :defaults_config
      end

      def start
        configured do
          write_config

          @thread = Thread.new do
            @mutex.synchronize do
              sleep_interval = nil
              loop do
                logger.debug "Waiting..."
                wait(sleep_interval)

                restart_needed = true

                if @changeset
                  update_state_with_changeset
                  restart_needed = @changeset.restart_needed?
                  @changeset = nil
                elsif @process.exited? and !sleep_interval
                  sleep_interval = @sleep_interval
                  logger.info "Haproxy exited abnormally. Sleeping for #{sleep_interval}s"
                  next
                end

                @file_descriptors = @socket_manager.update(@backends)
                write_config
                # TODO: figure out if the config has changed. if so, restart the process.

                sleep_interval = nil
                @process.restart(@file_descriptors.values) if restart_needed
              end
            end
          end
          @thread.abort_on_exception = true

          @process.on_stop do |status|
            Thread.new { signal }.join if @process.exited?
          end
          @process.start
        end
      end

      def socket?
        socket and socket.connected?
      end

      def update_state(backends, changeset)
        @mutex.synchronize do
          @changeset = changeset
          @backends  = backends
        end
        signal
      end

      def stop
        @thread.kill
        signal
        @thread.join
        begin
          @process.stop
        rescue Errno::ESRCH # sometimes there's no process here. that's OK.
        end
      end

      private

      def socket
        @socket ||= Socket.new
        @socket.path = @socket_path
        @socket
      end

      def update_state_with_changeset
        @changeset.disable.each do |backend, hosts|
          hosts.each { |host| socket.disable backend, host }
        end

        @changeset.enable.each do |backend, hosts|
          hosts.each { |host| socket.enable backend, host }
        end
      end

      def signal
        @mutex.synchronize { @cv.signal }
      end

      def wait(timeout = nil)
        @cv.wait(@mutex, timeout)
      end

      def write_config
        f = nil
        begin
          f = Tempfile.new('haproxy')
          f.write @config_template.result(binding)
          f.close
          Pathname.new(f.path).rename(config_file)
        rescue Exception => e
          logger.warn "Unable to write to #{config_file}: #{e}"
          File.unlink f.path if f
        end
      end
    end
  end
end

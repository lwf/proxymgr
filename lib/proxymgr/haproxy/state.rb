module ProxyMgr
  class Haproxy
    class State
      require 'tempfile'
      require 'pathname'
      require 'erb'

      include Logging

      def initialize(process, config_file, socket_manager, socket = nil, opts = {})
        @process         = process
        @config_file     = config_file
        @socket          = socket
        @socket_manager  = socket_manager

        @sleep_interval  = opts[:sleep_interval] || 5
        @global_config   = opts[:global]
        @defaults_config = opts[:defaults]
        @socket_path     = opts[:socket_path]

        @file_descriptors = {}
        @backends         = {}
        @config_template  = ERB.new(File.read(File.join(ProxyMgr.template_dir, 'haproxy.cfg.erb')))
        @mutex            = Mutex.new
        @cv               = ConditionVariable.new
      end

      def start
        write_config

        @thread = Thread.new do
          loop do
            logger.debug "Waiting..."
            wait

            sleep_interval = nil
            restart_needed = true

            @mutex.synchronize do
              if @changeset or @backends
                if @changeset
                  update_state_with_changeset
                  restart_needed = @changeset.restart_needed?
                end
                @file_descriptors = @socket_manager.update(@backends)
                write_config
                @changeset = nil
                @backends  = nil
              elsif @process.exited?
                sleep_interval = @sleep_interval
                logger.info "Haproxy exited abnormally. Sleeping for #{sleep_interval}s"
              end
            end

            sleep(sleep_interval) if sleep_interval # TODO: wait

            @process.restart(@file_descriptors.values) if restart_needed
          end
        end
        @thread.abort_on_exception = true

        @process.on_stop do |status|
          Thread.new { signal }.join if @process.exited?
        end
        @process.start
      end

      def socket?
        @socket and @socket.connected?
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

      def update_state_with_changeset
        @changeset.disable.each do |backend, hosts|
          hosts.each { |host| @socket.disable backend, host }
        end

        @changeset.enable.each do |backend, hosts|
          hosts.each { |host| @socket.enable backend, host }
        end
      end

      def signal
        @mutex.synchronize { @cv.signal }
      end

      def wait(timeout = nil)
        @mutex.synchronize { @cv.wait(@mutex, timeout) }
      end

      def write_config
        f = nil
        begin
          f = Tempfile.new('haproxy')
          f.write @config_template.result(binding)
          f.close
          Pathname.new(f.path).rename(@config_file)
        rescue Exception => e
          logger.warn "Unable to write to #{@config_file}: #{e}"
          File.unlink f.path if f
        end
      end
    end
  end
end

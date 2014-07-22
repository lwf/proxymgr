module ProxyMgr
  class Sink
    require 'absolute_time'

    include Logging

    def initialize(haproxy, opts = {})
      @file            = opts[:haproxy_config_file] || '/tmp/haproxy.cfg'
      @default_timeout = opts[:default_timeout] || 2
      @max_timeout     = opts[:max_timeout] || 10
      @haproxy         = haproxy
      @timeout         = nil
      @thread          = nil
      @cv              = ConditionVariable.new
      @mutex           = Mutex.new
      @backends        = nil
      @haproxy.start
      start
    end

    def update_backends(backends)
      @mutex.synchronize do
        @backends ||= {}
        backends.each do |name, watcher|
          next if watcher.servers.empty?
          @backends[name] = watcher
        end
      end
      signal
    end

    def shutdown
      @thread.kill
      @thread.join
      @haproxy.shutdown
    end

    private

    def start
      @thread = Thread.new do
        t1 = nil
        loop do
          if @timeout && t1 && AbsoluteTime.now - t1 >= @timeout && @backends
            @mutex.synchronize do
              @haproxy.update_backends(@backends)

              @timeout = nil
              @backends = nil
            end
          elsif t1
            set_timeout
            logger.debug "Waiting for #{@timeout}s or signal"
          end

          t1 = AbsoluteTime.now
          logger.debug 'Waiting to be signalled'
          wait
        end
      end
      @thread.abort_on_exception = true
    end

    def signal
      @mutex.synchronize { @cv.signal }
    end

    def wait
      @mutex.synchronize { @cv.wait(@mutex, @timeout) }
    end

    def set_timeout
      @timeout = @timeout ? @timeout * @timeout : @default_timeout
      @timeout = @max_timeout if @timeout > @max_timeout
    end
  end
end

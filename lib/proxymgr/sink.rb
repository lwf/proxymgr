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
      @start_cv        = ConditionVariable.new
      @start_mutex     = Mutex.new
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
        signal
      end
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
        @mutex.synchronize do
          loop do
            started! unless started?

            if @timeout && t1 && AbsoluteTime.now - t1 >= @timeout && @backends
              @haproxy.update_backends(@backends)

              @timeout = nil
              @backends = nil
            elsif t1
              set_timeout
              logger.debug "Waiting for #{@timeout}s or signal"
            end

            t1 = AbsoluteTime.now
            logger.debug 'Waiting to be signalled'
            wait
          end
        end
      end
      @thread.abort_on_exception = true

      wait_for_started
    end

    def signal
      @cv.signal
    end

    def wait
      @cv.wait(@mutex, @timeout)
    end

    def set_timeout
      @timeout = @timeout ? @timeout * @timeout : @default_timeout
      @timeout = @max_timeout if @timeout > @max_timeout
    end

    def started?
      @start_cv == nil
    end

    def started!
      @start_mutex.synchronize do
        @start_cv.signal
        @start_cv = nil
      end
    end

    def wait_for_started
      @start_mutex.synchronize do
        @start_cv.wait(@start_mutex) if @start_cv
      end
    end
  end
end

module Earthquake
  module Core
    attr_accessor :config

    def item_queue
      @item_queue ||= []
    end

    def inits
      @inits ||= []
    end

    def init(&block)
      inits << block
    end

    def load_config(*argv)
      # TODO: parse argv
      self.config = {
        :dir             => File.expand_path('~/.earthquake'),
        :consumer_key    => 'qOdgatiUm6HIRcdoGVqaZg',
        :consumer_secret => 'DHcL0bmS02vjSMHMrbFxCQqbDxh8yJZuLuzKviyFMo'
      }
      config[:file] ||= File.join(config[:dir], 'config')
      load config[:file]

      get_access_token unless self.config[:token] && self.config[:secret]
    end

    def start(*argv)
      load_config(*argv)

      Thread.abort_on_exception = true

      inits.each { |block| block.call(*argv) }

      EventMachine::run {
        @stream = ::Twitter::JSONStream.connect(
          :ssl   => true,
          :host  => 'userstream.twitter.com',
          :path  => '/2/user.json',
          :oauth => config.slice(:consumer_key, :consumer_secret).merge(:access_key => config[:token], :access_secret => config[:secret])
        )

        @stream.each_item do |item|
          item_queue << JSON.parse(item)
        end

        @stream.on_error do |message|
          $stdout.print "error: #{message}\n"
          $stdout.flush
        end

        @stream.on_reconnect do |timeout, retries|
          $stdout.print "reconnecting in: #{timeout} seconds\n"
          $stdout.flush
        end

        @stream.on_max_reconnects do |timeout, retries|
          $stdout.print "Failed after #{retries} failed reconnects\n"
          $stdout.flush
        end

        trap('TERM') { stop }
      }
    end

    def stop
      @stream.stop
      EventMachine.stop if EventMachine.reactor_running? 
    end

    def notify(message)
      Notify.notify 'earthquake', message
    end
  end
end

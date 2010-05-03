module APN
  # Encapsulates the logic necessary to convert an iPhone token and an array of options into a string of the format required
  # by Apple's servers to send the notification.  Much of the processing code here copied with many thanks from
  # http://github.com/samsoffes/apple_push_notification/blob/master/lib/apple_push_notification.rb
  #
  # APN::Notification.new's first argument is the token of the iPhone which should receive the notification.  The second argument
  # is a hash with any of :alert, :badge, and :sound keys. All three accept string arguments, while :sound can also be set to +true+
  # to play the default sound installed with the application. At least one of these keys must exist.  Any other keys are merged into
  # the root of the hash payload ultimately sent to the iPhone:
  #
  #   APN::Notification.new(token, {:alert => 'Stuff', :custom => {:code => 23}})
  #   # Writes this JSON to servers: {"aps" => {"alert" => "Stuff"}, "custom" => {"code" => 23}}
  # 
  # As a shortcut, APN::Notification.new also accepts a string as the second argument, which it converts into the alert to send.  The 
  # following two lines are equivalent:
  #
  #   APN::Notification.new(token, 'Some Alert')
  #   APN::Notification.new(token, {:alert => 'Some Alert'})
  #
  class Notification
    attr_accessor :options, :token
    def initialize(token, opts)
      @options = hash_as_symbols(opts.is_a?(Hash) ? opts : {:alert => opts})
      @token = token

      raise "The maximum size allowed for a notification payload is 256 bytes." if packaged_notification.size.to_i > 256
    end

    def to_s
      packaged_notification
    end
    
    # Ensures at least one of <code>%w(alert badge sound)</code> is present
    def valid?
      return true if %w(alert badge sound).any?{|key| options.keys.include?(key.to_sym) }
      false
    end
    
    protected

    # Completed encoded notification, ready to send down the wire to Apple
    def packaged_notification
      pt = packaged_token
      pm = packaged_message
      [0, 0, 32, pt, 0, pm.size, pm].pack("ccca*cca*") 
    end

    # Device token, compressed and hex-ified
    def packaged_token
      [@token.gsub(/[\s|<|>]/,'')].pack('H*')
    end

    # Converts the supplied options into the JSON needed for Apple's push notification servers.
    # Extracts :alert, :badge, and :sound keys into the 'aps' hash, merges any other hash data
    # into the root of the hash to encode and send to apple.
    def packaged_message
      hsh = {'aps' => {}}
      hsh['aps']['alert'] = @options.delete(:alert).to_s if @options[:alert]
      hsh['aps']['badge'] = @options.delete(:badge).to_i if @options[:badge]
      if sound = @options.delete(:sound)
        hsh['aps']['sound'] = sound.is_a?(TrueClass) ? 'default' : sound.to_s
      end
      hsh.merge!(@options)
      hsh.to_json
    end
    
    # Symbolize keys, using ActiveSupport if available
    def hash_as_symbols(hash)
      if hash.respond_to?(:symbolize_keys)
        return hash.symbolize_keys
      else
       hash.inject({}) do |opt, (key, value)|
         opt[(key.to_sym rescue key) || key] = value
         opt
       end
     end
   end
   
 end   
end
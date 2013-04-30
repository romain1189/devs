module DEVS
  # This class represent a DEVS atomic model.
  class AtomicModel < Model
    attr_accessor :elapsed, :time, :sigma

    # @!attribute sigma
    #   Sigma is a convenient variable introduced to simplify modeling phase
    #   and represent the next activation time (see {#time_advance})
    #   @return [Fixnum] Returns the sigma (σ) value

    # @!attribute elapsed
    #   This attribute is updated along simulation. It represents the elapsed
    #   time since the last transition.
    #   @return [Fixnum] Returns the elapsed time since the last transition

    # @!attribute time
    #   This attribute is updated along with simulation clock and
    #   represent the last simulation time at which this model
    #   was activated. Its default assigned value is {INFINITY}.
    #   @return [Fixnum] Returns the last activation time

    # syntax sugaring
    class << self
      # @!group Class level DEVS functions

      # Defines the external transition function (δext) using the given block
      # as body.
      #
      # @see #external_transition
      # @example
      #   external_transition do
      #     input_ports.each do |port|
      #       value = retrieve(port)
      #       puts "#{port.name} => #{value}"
      #     end
      #
      #     self.sigma = 0
      #   end
      # @return [void]
      def external_transition(&block)
        define_method(:external_transition, &block) if block
      end
      alias_method :ext_transition, :external_transition
      alias_method :delta_ext, :external_transition

      # Defines the internal transition function (δint) using the given block
      # as body.
      #
      # @see #internal_transition
      # @example
      #   internal_transition { self.sigma = DEVS::INFINITY }
      # @return [void]
      def internal_transition(&block)
        define_method(:internal_transition, &block) if block
      end
      alias_method :int_transition, :internal_transition
      alias_method :delta_int, :internal_transition

      # Defines the time advance function (ta) using the given block as body.
      #
      # @see #time_advance
      # @example
      #   time_advance { self.sigma }
      # @return [void]
      def time_advance(&block)
        define_method(:time_advance, &block) if block
      end

      # Defines the output function (λ) using the given block as body.
      #
      # @see #output
      # @example
      #   output do
      #     post(@some_value, output_ports.first)
      #   end
      # @return [void]
      def output(&block)
        define_method(:output, &block) if block
      end
      alias_method :lambda, :output

      # @!endgroup

      # @!group Class level Hook methods

      # Defines the post simulation hook method using the given block as body.
      #
      # @example
      #   post_simulation_hook do
      #     puts "Do whatever once the simulation has ended."
      #   end
      # @return [void]
      def post_simulation_hook(&block)
        define_method(:post_simulation_hook, &block) if block
      end

      # @!endgroup
    end

    # Returns a new instance of {AtomicModel}
    def initialize
      super

      @elapsed = 0.0
      @sigma = INFINITY
    end

    # Returns a boolean indicating if <i>self</i> is an atomic model
    #
    # @return [true]
    def atomic?
      true
    end

    # Returns a boolean indicating if <i>self</i> is an observer of hooks
    # events
    #
    # @api private
    # @return [Boolean] true if a hook method is defined, false otherwise
    def observer?
      self.respond_to? :post_simulation_hook
    end

    # Observer callback method. Dispatches the hook event to the appropriate
    # method
    #
    # @api private
    # @return [void]
    def update(hook, *args)
      self.send("#{hook}_hook", *args)
    end

    # Sends an output value to the specified output {Port}
    #
    # @param value [Object] the output value
    # @param port [Port, String, Symbol] the output port or its name
    # @return [Object] the posted output value
    # @raise [ArgumentError] if the given port is nil or doesn't exists
    # @raise [InvalidPortHostError] if the given port doesn't belong to this
    #   model
    # @raise [InvalidPortTypeError] if the given port isn't an output port
    def post(value, port)
      ensure_output_port(port).outgoing = value
    end

    # Retrieve a {Message} from the specified input {Port}
    #
    # @param port [Port, String, Symbol] the port or its name
    # @return [Message, nil] the input value if any, nil otherwise
    # @raise [ArgumentError] if the given port is nil or doesn't exists
    # @raise [InvalidPortHostError] if the given port doesn't belong to this
    #   model
    # @raise [InvalidPortTypeError] if the given port isn't an input port
    def retrieve(port)
      ensure_input_port(port).incoming
    end

    # Yield outgoing messages added by the DEVS lambda (λ) function for the
    # current state
    #
    # @note This method calls the DEVS lambda (λ) function
    # @api private
    # @yieldparam message [Message] the message that is yielded
    # @return [void]
    def fetch_output!
      self.output

      @output_ports.each do |port|
        value = port.outgoing
        yield(Message.new(value, port)) unless value.nil?
      end

      nil
    end

    # Append an incoming message to the appropriate port's mailbox.
    #
    # @api private
    # @param message [Message] the incoming message
    # @raise [InvalidPortHostError] if <i>self</i> is not the correct host
    #   for this message
    # @raise [InvalidPortTypeError] if the {Message#port} is not an input
    #   port
    def add_input_message(message)
      if message.port.host != self
        raise InvalidPortHostError, "The port associated with the given\
message #{message} doesn't belong to this model"
      end

      unless message.port.input?
        raise InvalidPortTypeError, "The port associated with the given\
message #{message} isn't an input port"
      end

      message.port.incoming = message.payload
    end

    # Returns a {Port} given a name or an instance and checks it.
    #
    # @param port [Port, String, Symbol] the port or its name
    # @return [Port] the matching port
    # @raise [ArgumentError] if the given port is nil or doesn't exists
    # @raise [InvalidPortHostError] if the given port doesn't belong to this
    #   model
    def ensure_port(port)
      raise ArgumentError, "port argument cannot be nil" if port.nil?
      if !port.respond_to?(:name)
        port = find_input_port_by_name(port)
        raise ArgumentError, "the given port doesn't exists" if port.nil?
      end

      unless port.host == self
        raise InvalidPortHostError, "The given port doesn't belong to this \
        model"
      end

      port
    end
    protected :ensure_port

    # Finds and checks if the given port is an input port
    #
    # @param port [Port, String, Symbol] the port or its name
    # @return [Port] the matching port
    # @raise [ArgumentError] if the given port is nil or doesn't exists
    # @raise [InvalidPortHostError] if the given port doesn't belong to this
    #   model
    # @raise [InvalidPortTypeError] if the given port isn't an input port
    def ensure_input_port(port)
      port = ensure_port(port)
      unless port.input?
        raise InvalidPortTypeError, "The given port isn't an input port"
      end
      port
    end
    protected :ensure_input_port

    # Finds and checks if the given port is an output port
    #
    # @param port [Port, String, Symbol] the port or its name
    # @return [Port] the matching port
    # @raise [ArgumentError] if the given port is nil or doesn't exists
    # @raise [InvalidPortHostError] if the given port doesn't belong to this
    #   model
    # @raise [InvalidPortTypeError] if the given port isn't an output port
    def ensure_output_port(port)
      port = ensure_port(port)
      unless port.output?
        raise InvalidPortTypeError, "The given port isn't an output port"
      end
      port
    end
    protected :ensure_output_port

    # @!group DEVS functions

    # The external transition function (δext), called each time a
    # message is sent to one of all {#input_ports}
    #
    # @abstract Override this method to implement the appropriate behavior of
    #   your model or define it with {AtomicModel.external_transition}
    # @see AtomicModel.external_transition
    # @example
    #   def external_transition
    #     input_ports.each do |port|
    #       value = retrieve(port)
    #       puts "#{port.name} => #{value}"
    #     end
    #
    #     self.sigma = 0
    #   end
    # @return [void]
    def external_transition; end

    # Internal transition function (δint), called when the model should be
    # activated, e.g when {#elapsed} reaches {#time_advance}
    #
    # @abstract Override this method to implement the appropriate behavior of
    #   your model or define it with {AtomicModel.internal_transition}
    # @see AtomicModel.internal_transition
    # @example
    #   def internal_transition; self.sigma = DEVS::INFINITY; end
    # @return [void]
    def internal_transition; end

    # Time advance function (ta), called after each transition to give a
    # chance to <i>self</i> to be active. By default returns {#sigma}
    #
    # @note Override this method to implement the appropriate behavior of
    #   your model or define it with {AtomicModel.time_advance}
    # @see AtomicModel.time_advance
    # @example
    #   def time_advance; self.sigma; end
    # @return [Fixnum] the time to wait before the model will be activated
    def time_advance
      @sigma
    end

    # The output function (λ)
    #
    # @abstract Override this method to implement the appropriate behavior of
    #   your model or define it with {AtomicModel.output}
    # @see AtomicModel.output
    # @example
    #   def output
    #     post(@some_value, output_ports.first)
    #   end
    # @return [void]
    def output; end

    # @!endgroup
  end
end
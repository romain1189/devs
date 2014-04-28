require 'set'
require 'logger'
require 'observer'

# @author Romain Franceschini <franceschini.romain@gmail.com>
module DEVS
  INFINITY = Float::INFINITY
end

require 'devs/version'
require 'devs/logging'
require 'devs/errors'
require 'devs/event'
require 'devs/message'
require 'devs/coupling'
require 'devs/port'
require 'devs/model'
require 'devs/atomic_model'
require 'devs/coupled_model'
require 'devs/processor'
require 'devs/simulator'
require 'devs/coordinator'
require 'devs/root_coordinator'
require 'devs/builders'
require 'devs/concurrency'
require 'devs/notifications'
require 'devs/parallel'
require 'devs/classic'

module DEVS
  # Runs a simulation
  #
  # @param formalism [Symbol] the formalism to use, either <tt>:pdevs</tt>
  #   for parallel devs (default) or <tt>:devs</tt> for classic devs
  # @example
  #   simulate do
  #     duration = 200
  #
  #   end
  def simulate(formalism=:pdevs, &block)
    namespace = case formalism
    when :pdevs then Parallel
    when :devs then Classic
    end

    start_time = Time.now
    DEVS.logger.info "*** Initializing simulation at #{start_time}"
    builder = Builders::SimulationBuilder.new(namespace, &block)
    init_time = Time.now - start_time
    DEVS.logger.info "*** Initialized simulation at #{init_time} after #{init_time - start_time} secs."
    builder.root_coordinator.simulate
  end
  module_function :simulate

  # Returns the current version of the gem
  #
  # @return [String] the string representation of the version
  def version
    VERSION
  end
  module_function :version
end

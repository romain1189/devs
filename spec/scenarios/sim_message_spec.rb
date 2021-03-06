require "spec_helper"

class MsgTestError < StandardError; end

class G < AtomicModel
  output_port :out

  attr_reader :output_calls, :int_calls

  attr_state :sigma, default: 1
  attr_state :output_calls, :int_calls, default: 0

  def output
    @output_calls += 1
    post "value", :out
  end

  def internal_transition
    @int_calls += 1
    raise MsgTestError unless @elapsed == 0
    @sigma = INFINITY
  end
end

class RPDEVS < AtomicModel
  input_port :in

  attr_reader :ext_calls, :int_calls, :output_calls
  attr_state :ext_calls, :int_calls, :output_calls, default: 0

  def external_transition(bag)
    @ext_calls += 1
    raise MsgTestError unless @elapsed == 1
    raise MsgTestError unless bag[input_port(:in)] == ["value", "value"]
  end
end

class RCDEVS < AtomicModel
  input_port :in

  attr_reader :ext_calls, :int_calls, :output_calls
  attr_state :ext_calls, :int_calls, :output_calls, default: 0

  def external_transition(bag)
    @ext_calls += 1
    if @ext_calls == 1
      raise MsgTestError unless @elapsed == 1
    elsif @ext_calls > 1
      raise MsgTestError unless @elapsed == 0
    end
    raise MsgTestError unless bag[input_port(:in)] == ["value"]
  end
end

class CDEVSMsgTestFlat < CoupledModel
  attr_reader :g1, :g2, :r
  attr_reader :select_calls

  def initialize
    super("test_cdevs_msg_flat")
    @select_calls = 0

    @r = RCDEVS.new :r
    @g1 = G.new :g1
    @g2 = G.new :g2

    self << @r << @g1 << @g2

    attach(:out, to: :in, between: :g1, and: :r)
    attach(:out, to: :in, between: :g2, and: :r)
  end

  def select(imm)
    @select_calls += 1
    super(imm)
  end
end

class CDEVSMsgTestCoupled < CoupledModel
  attr_reader :g1, :g2, :r
  attr_reader :select_calls

  def initialize
    super("test_cdevs_msg_coupled")
    @select_calls = 0

    @r = RCDEVS.new :R
    @g1 = G.new :G1
    @g2 = G.new :G2

    gen = CoupledModel.new(:gen)
    gen.add_output_port :out
    gen << @g1 << @g2
    gen.attach_output(:out, to: :out, of: @g1)
    gen.attach_output(:out, to: :out, of: @g2)

    recv = CoupledModel.new(:recv)
    recv.add_input_port :in
    recv << @r
    recv.attach_input(:in, to: :in, of: @r)

    self << gen << recv
    attach(:out, to: :in, between: gen, and: recv)
  end

  def select(imm)
    @select_calls += 1
    super(imm)
  end
end

class PDEVSMsgTestFlat < CoupledModel
  attr_reader :g1, :g2, :r

  def initialize
    super("test_pdevs_msg_flat")

    @r = RPDEVS.new :r
    @g1 = G.new :g1
    @g2 = G.new :g2

    self << @r << @g1 << @g2

    attach(:out, to: :in, between: :g1, and: :r)
    attach(:out, to: :in, between: :g2, and: :r)
  end
end

class PDEVSMsgTestCoupled < CoupledModel
  attr_reader :g1, :g2, :r

  def initialize
    super("test_pdevs_msg_coupled")

    @r = RPDEVS.new :R
    @g1 = G.new :G1
    @g2 = G.new :G2

    gen = CoupledModel.new(:gen)
    gen.add_output_port :out
    gen << @g1 << @g2
    gen.attach_output(:out, to: :out, of: @g1)
    gen.attach_output(:out, to: :out, of: @g2)

    recv = CoupledModel.new(:recv)
    recv.add_input_port :in
    recv << @r
    recv.attach_input(:in, to: :in, of: @r)

    self << gen << recv
    attach(:out, to: :in, between: gen, and: recv)
  end
end

describe "CDEVS message passing" do
  describe "with IC, EOC and EIC couplings involved" do
    describe "transition are properly called" do
      it "for full hierarchy" do
        m = CDEVSMsgTestCoupled.new
        sim = Simulation.new(m, maintain_hierarchy: true, formalism: :cdevs)
        sim.simulate

        m.select_calls.must_equal(0)

        m.r.ext_calls.must_equal(2)
        m.r.int_calls.must_equal(0)
        m.r.output_calls.must_equal(0)

        m.g1.int_calls.must_equal(1)
        m.g2.int_calls.must_equal(1)

        m.g1.output_calls.must_equal(1)
        m.g2.output_calls.must_equal(1)
      end

      it "with flattening" do
        m = CDEVSMsgTestCoupled.new
        sim = Simulation.new(m, maintain_hierarchy: false, formalism: :cdevs)
        sim.simulate

        m.select_calls.must_equal(1)

        m.r.ext_calls.must_equal(2)
        m.r.int_calls.must_equal(0)
        m.r.output_calls.must_equal(0)

        m.g1.int_calls.must_equal(1)
        m.g2.int_calls.must_equal(1)

        m.g1.output_calls.must_equal(1)
        m.g2.output_calls.must_equal(1)
      end
    end
  end

  describe "with IC couplings only" do
    describe "transition are properly called" do
      it "for full hierarchy" do
        m = CDEVSMsgTestFlat.new
        sim = Simulation.new(m, maintain_hierarchy: true, formalism: :cdevs)
        sim.simulate

        m.select_calls.must_equal 1

        m.r.ext_calls.must_equal(2)
        m.r.int_calls.must_equal(0)
        m.r.output_calls.must_equal(0)

        m.g1.int_calls.must_equal(1)
        m.g2.int_calls.must_equal(1)

        m.g1.output_calls.must_equal(1)
        m.g2.output_calls.must_equal(1)
      end

      it "with flattening" do
        m = CDEVSMsgTestFlat.new
        sim = Simulation.new(m, maintain_hierarchy: false, formalism: :cdevs)
        sim.simulate

        m.select_calls.must_equal 1

        m.r.ext_calls.must_equal(2)
        m.r.int_calls.must_equal(0)
        m.r.output_calls.must_equal(0)

        m.g1.int_calls.must_equal(1)
        m.g2.int_calls.must_equal(1)

        m.g1.output_calls.must_equal(1)
        m.g2.output_calls.must_equal(1)
      end
    end
  end
end

describe "PDEVS message passing" do
  describe "with IC, EOC and EIC couplings involved" do
    describe "transition are properly called" do
      it "for full hierarchy" do
        m = PDEVSMsgTestCoupled.new
        sim = Simulation.new(m, maintain_hierarchy: true)
        sim.simulate

        m.r.ext_calls.must_equal(1)
        m.r.int_calls.must_equal(0)
        m.r.output_calls.must_equal(0)

        m.g1.int_calls.must_equal(1)
        m.g2.int_calls.must_equal(1)

        m.g1.output_calls.must_equal(1)
        m.g2.output_calls.must_equal(1)
      end

      it "with flattening" do
        m = PDEVSMsgTestCoupled.new
        sim = Simulation.new(m, maintain_hierarchy: false)
        sim.simulate

        m.r.ext_calls.must_equal(1)
        m.r.int_calls.must_equal(0)
        m.r.output_calls.must_equal(0)

        m.g1.int_calls.must_equal(1)
        m.g2.int_calls.must_equal(1)

        m.g1.output_calls.must_equal(1)
        m.g2.output_calls.must_equal(1)
      end
    end
  end

  describe "with IC couplings only" do
    describe "transition are properly called" do
      it "for full hierarchy" do
        m = PDEVSMsgTestFlat.new
        sim = Simulation.new(m, maintain_hierarchy: true)
        sim.simulate

        m.r.ext_calls.must_equal(1)
        m.r.int_calls.must_equal(0)
        m.r.output_calls.must_equal(0)

        m.g1.int_calls.must_equal(1)
        m.g2.int_calls.must_equal(1)

        m.g1.output_calls.must_equal(1)
        m.g2.output_calls.must_equal(1)
      end

      it "with flattening" do
        m = PDEVSMsgTestFlat.new
        sim = Simulation.new(m, maintain_hierarchy: false)
        sim.simulate

        m.r.ext_calls.must_equal(1)
        m.r.int_calls.must_equal(0)
        m.r.output_calls.must_equal(0)

        m.g1.int_calls.must_equal(1)
        m.g2.int_calls.must_equal(1)

        m.g1.output_calls.must_equal(1)
        m.g2.output_calls.must_equal(1)
      end
    end
  end
end

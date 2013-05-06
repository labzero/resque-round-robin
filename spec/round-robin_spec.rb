require "spec_helper"

describe "RoundRobin" do

  before(:each) do
    Resque.redis.flushall
  end

  context "a worker" do
    it "switches queues, round robin" do
      5.times { Resque::Job.create(:q1, SomeJob) }
      5.times { Resque::Job.create(:q2, SomeJob) }

      worker = Resque::Worker.new(:q1, :q2)

      worker.process
      Resque.size(:q1).should == 5
      Resque.size(:q2).should == 4

      worker.process
      Resque.size(:q1).should == 4
      Resque.size(:q2).should == 4
    end

    it "adds priority and switches queues, round robin" do
      2.times { Resque::Job.create(:_priority_q0, SomeJob) }
      5.times { Resque::Job.create(:q1, SomeJob) }
      5.times { Resque::Job.create(:q2, SomeJob) }

      worker = Resque::Worker.new('*')

      worker.process
      Resque.size(:_priority_q0).should == 1
      Resque.size(:q1).should == 5
      Resque.size(:q2).should == 5

      worker.process
      Resque.size(:_priority_q0).should == 0
      Resque.size(:q1).should == 5
      Resque.size(:q2).should == 5

      worker.process
      Resque.size(:_priority_q0).should == 0
      Resque.size(:q1).should == 5
      Resque.size(:q2).should == 4

      worker.process
      Resque.size(:_priority_q0).should == 0
      Resque.size(:q1).should == 4
      Resque.size(:q2).should == 4
    end
    it 'skips a queue that is being processed by another worker'
  end

  it "should pass lint" do
    Resque::Plugin.lint(Resque::Plugins::RoundRobin)
  end
  
end

require 'helper'

class TestResqueBatchworker < Test::Unit::TestCase
  should "be a valid plugin" do
    assert_nothing_raised do
      Resque::Plugin.lint(Resque::Plugins::Batchworker)
    end
  end
  should "process 2 jobs with 2 workers" do
    4.times {|i| Resque.enqueue(BatchJob, i)}
    Resque::Plugins::Batchworker.initiate_work 2, :test
    redis = Redis.new
    pids = []
    while pid = redis.rpop(:batch_job_test)
      pids << pid
    end
    assert_equal pids.size, 4
    assert_equal pids.uniq.size, 2
  end
end

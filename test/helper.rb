require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'redis'
require 'active_support'
require 'resque'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'resque-batchworker'

class Test::Unit::TestCase
end

class BatchJob
  @queue = :test
  
  def self.perform(args)
    r = Redis.new
    r.rpush :batch_job_test, Process.pid
  end
end
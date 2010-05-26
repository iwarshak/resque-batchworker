module Resque
  module Plugins
    class Batchworker < Resque::Worker
      include Resque::Helpers
      extend Resque::Helpers

      def work(worker_number, &block)
        # This runs in a child process
        $0 = "resque: Starting"
        run_hook :after_fork
        prune_dead_workers
        register_worker
      
        @logger = Logger.new("batchworker.log")
        @logger.debug("about to start a forked worker with count #{worker_number}")
        @logger.debug("inside safe_fork #{Process.pid}")
        job_counter = 0
        begin
          @logger.debug("about to register worker #{Process.pid}")
          @logger.debug("#{Process.pid } registered worker! about to look for a job")
          while job = reserve
            @logger.info("#{Process.pid } found job #{job}")
            working_on(job)
            procline "#{self} Processing #{job.queue} since #{Time.now.to_i} number:#{worker_number}"
            perform(job, &block)
            job_counter += 1
          end
        ensure
          @logger.info "#{self} processed #{job_counter} jobs"
          @logger.info "#{Process.pid } unregistering worker #{self}"
          unregister_worker
        end
      end
  
  
      def self.initiate_work(count, queue, &block)
        count ||= 1
        self.new(queue.to_sym).startup # Want this to be called before forking
      
        safe_fork(count.to_i) do |worker_number|
          worker = self.new(queue.to_sym)
          worker.work(worker_number)
        end
      end

      def perform(job = nil)
        return unless job ||= reserve
      
        begin
          # We don't want this called here because we only want it called once. 
          # run_hook :after_fork, job 
          @logger.error("#{Process.pid} performing #{job}")
          job.perform
        rescue Object => e
          log "#{job.inspect} failed: #{e.inspect}"
          job.fail(e)
          failed!
        else
          log "done: #{job.inspect}"
        ensure
          yield job if block_given?
          done_working
        end
      end

      undef fork if method_defined?(:fork)

      def startup
        enable_gc_optimizations
        # register_signal_handlers # This won't work, so remove it.
        run_hook :before_first_fork
        run_hook :before_fork

        # Fix buffering so we can `rake resque:work > resque.log` and
        # get output from the child in there.
        $stdout.sync = true
      end

      def prune_dead_workers
        all_workers = self.class.all # the only change here. 
        known_workers = worker_pids unless all_workers.empty?
        all_workers.each do |worker|
          host, pid, queues = worker.id.split(':')
          next unless host == hostname
          next if known_workers.include?(pid)
          log! "Pruning dead worker: #{worker}"
          worker.unregister_worker
        end
      end

    end
  end
end
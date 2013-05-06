
module Resque::Plugins
  module RoundRobin
    def filter_busy_queues qs
      busy_queues = Resque::Worker.working.map { |worker| worker.job["queue"] }.compact
      Array(qs.dup).compact - busy_queues
    end

    def rotated_queues
      @n ||= 0
      @n += 1
      # since we rely on the resque-dynamic-queues plugin, this is all the queues, expanded out
      queues_hash = priority_queues_hash queues
      if queues_hash[:norm].size > 0
        @n = @n % queues_hash[:norm].size
        queues_hash[:priority] + queues_hash[:norm].rotate(@n)
      else
        queues_hash[:priority] + queues_hash[:norm]
      end
    end

    def queue_depth queuename
      busy_queues = Resque::Worker.working.map { |worker| worker.job["queue"] }.compact
      # find the queuename, count it.
      busy_queues.select {|q| q == queuename }.size
    end

    DEFAULT_QUEUE_DEPTH = 0
    def should_work_on_queue? queuename
      return true if @queues.include? '*'  # workers with QUEUES=* are special and are not subject to queue depth setting
      max = DEFAULT_QUEUE_DEPTH
      unless ENV["RESQUE_QUEUE_DEPTH"].nil? || ENV["RESQUE_QUEUE_DEPTH"] == ""
        max = ENV["RESQUE_QUEUE_DEPTH"].to_i
      end
      return true if max == 0 # 0 means no limiting
      cur_depth = queue_depth(queuename)
      log! "queue #{queuename} depth = #{cur_depth} max = #{max}"
      return true if cur_depth < max
      false
    end

    def reserve_with_round_robin
      qs = rotated_queues
      # then break them into 2 buckets - priority and norm; prepending the priority based ones first

      qs.each do |queue|
        log! "Checking #{queue}"
        if should_work_on_queue?(queue) && job = Resque::Job.reserve(queue)
          log! "Found job on #{queue}"
          return job
        end
        # Start the next search at the queue after the one from which we pick a job.
        @n += 1 unless is_queue_priority queue
      end

      nil
    rescue Exception => e
      log "Error reserving job: #{e.inspect}"
      log e.backtrace.join("\n")
      raise e
    end

    def priority_queues_hash(qs)
      queue_hash = {}
      queue_hash[:priority] = []
      queue_hash[:norm] = []
      qs.each do |q|
        if is_queue_priority q
          queue_hash[:priority] << q
        else
          queue_hash[:norm] << q
        end
      end
      queue_hash
    end

    def self.included(receiver)
      receiver.class_eval do
        alias reserve_without_round_robin reserve
        alias reserve reserve_with_round_robin
      end
    end

    private

    def is_queue_priority(q)
      q =~ /^_priority_/
    end

  end # RoundRobin
end # Resque::Plugins


module DEVS

  # A fast O(1) priority queue implementation
  class CalendarQueue
    attr_reader :size

    # @!attribute [r] size
    #   This attribute returns the total number of events in <i>self</i>.
    #   @return [Fixnum] Returns the total number of events

    def initialize(elements = nil, start_priority=0.0, bucket_count=2, bucket_width=1.0)
      @size = 0
      @resize_enabled = true

      # the bucket index from which the last event was dequeued
      @last_bucket = 0
      # the priority at the top of that bucket (highest priority that could go
      # into the bucket)
      @bucket_top = 0
      # the priority of the last event dequeued
      @last_priority = 0

      local_init(bucket_count, bucket_width, start_priority)
    end

    def inspect
      "<#{self.class}: size=#{@size}, bucket_width=#{@width}, last_priority=#{@last_priority}, last_bucket=#{@last_bucket}, bucket_top=#{@bucket_top}, shrink_threshold=#{@shrink_threshold}, expand_threshold=#{@expand_threshold}>"
    end

    def empty?
      @size == 0
    end

    def <<(obj)
      tn = obj.time_next
      i = tn / @width       # virtual bucket
      i = i % @buckets.size # actual bucket

      bucket = @buckets[i]
      if bucket.empty?
        bucket << obj
      else
        j = bucket.size - 1
        j -= 1 while tn > bucket[j].time_next && j >= 0
        bucket.insert(j + 1, obj)
      end

      @size += 1

      # double the calendar size if needed
      resize(2 * @buckets.size) if @size > @expand_threshold

      self
    end
    alias_method :push, :<<

    def delete(obj)
      tn = obj.time_next
      i = tn / @width       # virtual bucket
      i = i % @buckets.size # actual bucket

      bucket = @buckets[i]
      item = nil
      index = bucket.index(obj)
      if index
        item = bucket.delete_at(index)
        @size -= 1
      end

      # halve calendar size if needed
      resize(@buckets.size / 2) if @size < @shrink_threshold

      item
    end

    def peek
      return nil if @size == 0

      i = @last_bucket
      while i < @buckets.size
        bucket = @buckets[i]

        if bucket.size > 0 && bucket.last.time_next < @bucket_top
          # found item to dequeue
          item = bucket.last
          @last_bucket = i

          return item
        else
          # prepare to check next bucket or else go to a direct search
          i += 1
          i = 0 if i == @buckets.size
          @bucket_top += @width

          break if i == @last_bucket # go to direct search
        end
      end

      # directly search for minimum priority event
      lowest = Float::INFINITY
      i = tmp = 0
      while i < @buckets.size
        bucket = @buckets[i]
        if bucket.size > 0 && bucket.last.time_next < lowest
          lowest = bucket.last.time_next
          tmp = i
        end
        i += 1
      end
      @last_bucket = tmp
      @bucket_top = (((lowest / @width) + 1).to_i * @width + (0.5 * @width)).to_f
      peek
    end

    def pop
      return nil if @size == 0

      i = @last_bucket
      while i < @buckets.size
        bucket = @buckets[i]

        if bucket.size > 0 && bucket.last.time_next < @bucket_top
          # found item to dequeue
          item = bucket.pop
          @last_bucket = i
          @last_priority = item.time_next
          @size -= 1

          # halve calendar size if needed
          resize(@buckets.size / 2) if @size < @shrink_threshold

          return item
        else
          # prepare to check next bucket or else go to a direct search
          i += 1
          i = 0 if i == @buckets.size
          @bucket_top += @width

          break if i == @last_bucket # go to direct search
        end
      end

      # directly search for minimum priority event
      lowest = DEVS::INFINITY
      i = tmp = 0
      while i < @buckets.size
        bucket = @buckets[i]
        if bucket.size > 0 && bucket.last.time_next < lowest
          lowest = bucket.last.time_next
          tmp = i
        end
        i += 1
      end
      @last_bucket = tmp
      @last_priority = lowest
      @bucket_top = (((lowest / @width) + 1).to_i * @width + (0.5 * @width)).to_f
      pop
    end

    private

    # Initializes a bucket array within
    def local_init(bucket_count, bucket_width, start_priority)
      @width = bucket_width
      old = @buckets
      @buckets = if @cached_buckets == nil
        Array.new(bucket_count) { [] }
      else
        n = @cached_buckets.size
        if bucket_count < n
          # shrink the array
          @cached_buckets.slice!(bucket_count, n)
        else
          # expand the array
          @cached_buckets.fill(n, bucket_count - n) { [] }
        end
        @cached_buckets
      end
      @cached_buckets = old

      @last_priority = start_priority
      i = start_priority / bucket_width # virtual bucket
      @last_bucket = i % bucket_count
      @bucket_top = (i+1) * bucket_width + 0.5 * bucket_width

      # set up queue size change thresholds
      @shrink_threshold = bucket_count / 2 - 2
      @expand_threshold = 2 * bucket_count
    end

    # Resize buckets to new_size.
    def resize(new_size)
      return unless @resize_enabled

      bucket_width = new_width # find new bucket width
      local_init(new_size, bucket_width, @last_priority)

      i = 0
      while i < @cached_buckets.size
        bucket = @cached_buckets[i]
        @size -= bucket.size
        while obj = bucket.pop
          self << obj
        end
        i += 1
      end
    end

    # Calculates the width to use for buckets
    def new_width
      # decides how many queue elements to sample
      return 1.0 if @size < 2
      n = if @size <= 5
        @size
      else
        5 + (@size / 10).to_i
      end
      n = 25 if n > 25

      # record variables
      tmp_last_bucket = @last_bucket
      tmp_last_priority = @last_priority
      tmp_bucket_top = @bucket_top

      # dequeue n events from the queue and record their priorities with
      # resize_enabled set to false.
      @resize_enabled = false
      tmp = Array.new(n)
      average = 0.0
      i = 0
      while i < n
        # dequeue events to get a test sample
        tmp[i] = self.pop
        # and sum up the differences in time
        average += tmp[i].time_next - tmp[i-1].time_next if i > 0
        i += 1
      end

      # calculate average separation of sampled events
      average = average / (n-1).to_f

      # put the first sample back onto the queue
      self << tmp[0]

      # recalculate average using only separations smaller than twice the
      # original average
      new_average = 0.0
      j = 0
      i = 1
      while i < n
        sub = tmp[i].time_next - tmp[i-1].time_next
        if sub < average * 2.0
          new_average += sub
          j += 1
        end
        # put the remaining samples back onto the queue
        self << tmp[i]
        i += 1
      end

      # restore variables
      @resize_enabled = true
      @last_bucket = tmp_last_bucket
      @last_priority = tmp_last_priority
      @bucket_top = tmp_bucket_top

      # this is the new width
      (new_average / j.to_f) * 3.0
    end
  end
end

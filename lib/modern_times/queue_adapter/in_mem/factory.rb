module ModernTimes
  module QueueAdapter
    module InMem
      module Factory
        extend self

        def init
          @queue_hash             = {}
          @topic_hash             = {}
          @queue_reply_hash       = {}
          @topic_reply_hash       = {}
          @queue_hash_mutex       = Mutex.new
          @topic_hash_mutex       = Mutex.new
          @queue_reply_hash_mutex = Mutex.new
          @topic_reply_hash_mutex = Mutex.new
        end

        def get_worker_queue(worker_name, queue_name, topic_name, queue_max_size)
          if queue_name
            @queue_hash_mutex.synchronize do
              queue = @queue_hash[queue_name] ||= Queue.new(queue_name)
              queue.max_size = queue_max_size
              return queue
            end
          else
            @topic_hash_mutex.synchronize do
              topic = @topic_hash[topic_name] ||= Topic.new(topic_name)
              return topic.get_worker_queue(worker_name, queue_max_size)
            end
          end
        end

        def get_publisher_queue(queue_name, topic_name)
          if queue_name
            @queue_hash_mutex.synchronize do
              return @queue_hash[queue_name] ||= Queue.new(queue_name)
            end
          else
            @topic_hash_mutex.synchronize do
              return @topic_hash[topic_name] ||= Topic.new(topic_name)
            end
          end
        end

        def create_reply_queue(queue_name, topic_name, message_id, total_allowed_replies)
          if queue_name
            @queue_reply_hash_mutex.synchronize do
              return do_create_reply_queue(@queue_reply_hash, queue_name, message_id, total_allowed_replies)
            end
          else
            @topic_hash_mutex.synchronize do
              return do_create_reply_queue(@topic_reply_hash, topic_name, message_id, total_allowed_replies)
            end
          end
        end

        def find_reply_queue(queue_name, topic_name, message_id)
          if queue_name
            @queue_reply_hash_mutex.synchronize do
              return do_find_reply_queue(@queue_reply_hash, queue_name, message_id)
            end
          else
            @topic_hash_mutex.synchronize do
              return do_find_reply_queue(@topic_reply_hash, topic_name, message_id)
            end
          end
        end

        def delete_reply_queue(queue_name, topic_name, message_id)
          if queue_name
            @queue_reply_hash_mutex.synchronize do
              return do_delete_reply_queue(@queue_reply_hash, queue_name, message_id)
            end
          else
            @topic_hash_mutex.synchronize do
              return do_delete_reply_queue(@topic_reply_hash, topic_name, message_id)
            end
          end
        end

        #######
        private
        #######

        def do_create_reply_queue(reply_hash, name, message_id, total_allowed_replies)
          mid_hash = reply_hash[name] ||= {}
          # Hack to prevent potential memory leak if PublishHandle#read_response never gets called
          while mid_hash.size >= total_allowed_replies
            # For ordered hashes (JRuby and MRI 1.9) this will work all right, otherwise will drop random mid's
            mid_hash.delete(mid_hash.keys.first)
          end
          return mid_hash[message_id] = ReplyQueue.new("#{name}:#{message_id}")
        end

        def do_find_reply_queue(reply_hash, name, message_id)
          reply_hash[name] && reply_hash[name][message_id]
        end

        def do_delete_reply_queue(reply_hash, name, message_id)
          reply_hash[name] && reply_hash[name].delete(message_id)
        end
      end
      Factory.init
    end
  end
end

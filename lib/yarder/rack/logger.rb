module Yarder

  module Rack

    class Logger

      def initialize(app, tags = nil)
        @app, @tags = app, tags.presence
      end

      def call(env)

        t1 = Time.now
        request = ActionDispatch::Request.new(env)

        event = Yarder::Event.create Rails.logger, tags(request), true
        event['message'] = "#{request.request_method} #{request.filtered_path} for #{request.ip}"
        event.fields['client_ip'] = request.ip
        event.fields['method'] = request.request_method
        event.fields['path'] = request.filtered_path

        Yarder.log_entries[Thread.current] = event

        status, headers, response = @app.call(env)
        [status, headers, response]

      ensure
        if event
          event.fields['total_duration'] = (Time.now - t1)*1000
          event.fields['status'] = status

          ['rendering','sql'].each do |type|
            if event.fields[type] && !event.fields[type].empty?
              duration = event.fields[type].inject(0) {|result, local_event| result += local_event['duration'].to_f }
              event.fields["#{type}_duration"] = duration
            end
          end

          event.write(true)
        end

        Yarder.log_entries[Thread.current] = nil
      end

      def tags(request)
        return unless @tags
        @tags.reduce([]) do |arr, tag|
          case tag
          when Symbol
            arr << {tag.to_s => request.send(tag) }
          when Proc
            arr << tag.call(request)
          else
            arr << tag
          end
        end
      end

    end

  end

end

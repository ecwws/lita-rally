require 'rest-client'
require 'json'
require 'rally_api'

module Lita
  module Handlers
    class Rally < Handler

      RALLY = "https://rally1.rallydev.com/slm/webservice"
      HIPCHAT = 'https://api.hipchat.com/v2'

      @@key_map = {
        'de' => {
          name: 'defect',
          extra_output: [
            'State',
            'ScheduleState',
            'Severity',
            ['Release', '_refObjectName'],
          ],
        },
        'ds' => {
            name: 'defectsuite',
            extra_output: [
              'ScheduleState',
            ]
        },
        'f' => {
          name: 'feature',
          query_path: 'portfolioitem/feature',
          extra_output: [
            ['State', '_refObjectName'],
            ['Parent', '_refObjectName'],
          ]
        },
        'i' => {
          name: 'initiative',
          query_path: 'portfolioitem/initiative',
          extra_output: [
            ['State', '_refObjectName'],
            ['Parent', '_refObjectName'],
          ]
        },
        't' => {
          name: 'theme',
          query_path: 'portfolioitem/theme',
          extra_output: [
            ['State', '_refObjectName'],
            ['Parent', '_refObjectName'],
          ]
        },
        'ta' => {
          name: 'task',
          extra_output: [
            'State',
            ['WorkProduct', '_refObjectName'],
          ]
        },
        'tc' => {
          name: 'testcase',
          extra_output: [
            ['WorkProduct', '_refObjectName'],
            'Type',
          ]
        },
        'us' => {
          name: 'story',
          query_path: 'hierarchicalrequirement',
          link_path: 'userstory',
          extra_output: [
            'ScheduleState',
            ['Release', '_refObjectName'],
            ['Parent', '_refObjectName'],
            ['Feature', '_refObjectName'],
          ]
        }
      }

      config :username, type: String, required: true
      config :password, type: String, required: true
      config :api_version, type: String, default: 'v2.0'
      config :read_only, type: Object, default: false
      config :action_state_map, type: Hash, default: {
        'start' => 'Submitted',
        'pause' => 'Submitted',
        'backlog' => 'Submitted',
        'finish' => 'Fixed',
        'accept' => 'Closed',
      }
      config :action_schedule_state_map, type: Hash, default: {
        'start' => 'In-Progress',
        'pause' => 'Defined',
        'finish' => 'Completed',
        'accept' => 'Accepted',
        'backlog' => 'Backlog',
      }
      config :action_task_state_map, type: Hash, default: {
        'start' => 'In-Progress',
        'pause' => 'Defined',
        'backlog' => 'Defined',
        'finish' => 'Completed',
        'accept' => 'Completed',
      }
      config :hipchat_token, type: String, default: nil

      route(/^rally me ([[:alpha:]]+)(\d+)/, :rally_show, command: true, help: {
        'rally me <identifier>' => 'Show me that rally object'
      })

      route(/^rally me release stats for (.+)/, :rally_release_stats,
            command: true, help: {
        'rally me release count for <release>' => 'Count US and DE for release'
      })

      route(/^rally me release info for (.+)/, :rally_release_info,
            command: true, help: {
        'rally me release info for <release>' => 'Show release info'
      })

      route(/^rally find (defect|defects|story|stories) (contain|contains) "(.+)" in (name|description)$/,
            :rally_find, command: true, help: {
        'rally find <defect|story> contains "<search term>" ' \
        'in <name|description>' => 'Find the story or defect'
      })

      route(/^rally (start|pause|finish|accept|backlog) ([[:alpha:]]+)(\d+)/,
        :rally_mark, command: true, help: {
          'rally <start|pause|finish|accept|backlog> <formattedID>' =>
          'Move issues between scheduling states'
      })

      route(/^rally query (\w+)\s+(.*)$/,
        :rally_query_raw, command: true, help: { 'rally query <type> <query>' =>
          'execute raw query on rally on type of object'
      })

      route(/^rally find defect[s]{0,1} (created|closed) between (.+) and (.+)/,
        :rally_find_defect_range, command: true, help: {
          'rally find defect <created|closed> between <date> and <date>' =>
            'Find defect objects in date range'
      })

      route(
        /^rally find defect[s]{0,1} (created|closed) in last (\d+) day[s]{0,1}/,
        :rally_find_defect_back, command: true, help: {
          'rally find defect <created|closed> in last <number> days' =>
            'Find defect objects in date range'
      })

      route(/^rally mine/, :rally_find_mine, command: true, help: {
          'rally mine' =>
            '(HipChat Only) Find all defects/stories/tasks belongs to me'
      })

      route(/^rally my (defect|defects|story|stories|task|tasks)/,
            :rally_find_my, command: true, help: {
              'rally my <defect|story|task>' =>
                '(HipChat Only) Find defects/stories/tasks belongs to me'
      })

      route(/^rally for (.+)$/, :rally_find_mention, command: true, help: {
          'rally for (@)mention' =>
            '(HipChat Only) Find all defects/stories/tasks belongs to @mention'
      })

      route(/^rally (defect|defects|story|stories|task|tasks) for (.+)$/,
            :rally_find_mention, command: true, help: {
              'rally <defect|story|task> for (@)mention' =>
                '(HipChat Only) Find defects/stories/tasks belongs to @mention'
      })

      route(/^rally claim ([[:alpha:]]+)(\d+)/,
            :rally_assign, command: true, help: {
          'rally claim <FormattedID>' =>
            "(HipChat Only) claim an object's ownership"
      })

      route(/^rally assign ([[:alpha:]]+)(\d+) to (.+)$/,
            :rally_assign, command: true, help: {
          'rally assign <FormattedID> to (@)mention' =>
            "(HipChat Only) assign ownership of object to (@)mention"
      })

      route(/^rally list (backlog|defined|active|completed) (defect|defects|story|stories|task|tasks) in (.+)/,
            :rally_list_in_project, command: true, help: {
          'rally list <backlog|defined|active|completed> ' \
          '<defect|defects|story|stories|task|tasks> in <project>' =>
            'List defect/story/task in project'
      })

      def rally_list_in_project(response)
        state = response.matches[0][0]
        type = response.matches[0][1]
        project = response.matches[0][2].capitalize

        type = 'story' if type == 'stories'
        type = type[0..-2] if !type.nil? && type[-1] == 's'

        case state
        when 'defined','completed'
          state.capitalize!
        when 'backlog'
          raise 'There is no backlog state for task!' if type == 'task'
          state.capitalize!
        when 'active'
          state = 'In-Progress'
        end

        field = (type == 'task' ? 'State' : 'ScheduleState')

        term = "((#{field} = \"#{state}\") AND (Project.name = \"#{project}\"))"

        response.reply(rally_search(type, term, field))

      end

      def rally_assign(response)
        if config.hipchat_token
          if config.read_only
            response.reply('Rally plugin is operating in Read-Only mode, ' \
                           'ask your chat-ops admin to disable it.')
            return
          end

          type = response.matches[0][0].downcase
          id = response.matches[0][1]
          owner = response.matches[0][2]

          mention = owner.nil? ? response.user.mention_name : owner

          user = rally_find_user(hipchat_find_user(mention))

          response.reply(update_object(type, id, 'owner', user, options = {}))

          update_object(type, id, 'Notes',
                        "<br />assigned ownership to #{user} by " \
                        "#{response.user.name} on " \
                        "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S%z')}",
                        append: true)
        else
          response.reply('This is a HipChat only function, please provide '\
                         'hipchat_token to use this function.')
        end
      rescue Exception => e
        response.reply("Error during assignment: #{e}")
      end

      def rally_find_mention(response)
        if config.hipchat_token
          p1 = response.matches[0][0]
          p2 = response.matches[0][1]

          type, user =
            if %w{defect defects story stories task tasks}.include?(p1)
              [p1, p2]
            else
              [nil, p1]
            end

          email = hipchat_find_user(user)

          raise "Could not find user's email" unless email

          type = 'story' if type == 'stories'
          type = type[0..-2] if !type.nil? && type[-1] == 's'

          if type
            response.reply(rally_find_type(type, email))
          else
            response.reply(
              %w{story defect task}.inject("") do |output,type|
                output += "#{type.capitalize}:\n#{rally_find_type(type, email)}"
              end
            )
          end
        else
          response.reply('This is a HipChat only function, please provide '\
                         'hipchat_token to use this function.')
        end
      rescue Exception => e
        response.reply("Error occured: #{e}")
      end

      def rally_find_my(response)
        if config.hipchat_token
          email = hipchat_find_user(response.user.mention_name)

          raise "Your email is not found in Rally" unless email

          type = response.matches[0][0]

          type = 'story' if type == 'stories'
          type = type[0..-2] if type[-1] == 's'

          response.reply(rally_find_type(type, email))
        else
          response.reply('This is a HipChat only function, please provide '\
                         'hipchat_token to use this function.')
        end
      rescue Exception => e
        response.reply("Error occured: #{e}")
      end

      def rally_find_mine(response)
        if config.hipchat_token
          email = hipchat_find_user(response.user.mention_name)

          raise "Your email is not found in Rally" unless email

          response.reply(
            %w{story defect task}.inject("") do |output,type|
              output += "#{type.capitalize}:\n#{rally_find_type(type, email)}"
            end
          )

        else
          response.reply('This is a HipChat only function, please provide '\
                         'hipchat_token to use this function.')
        end
      rescue Exception => e
        response.reply("Error occured: #{e}")
      end

      def rally_find_defect_back(response)
        field =
          response.matches[0][0] == 'created' ? 'CreationDate' : 'ClosedDate'
        dt1 = (Time.now.to_date - response.matches[0][1].to_i).to_datetime
        dt2 = Time.now.to_datetime.to_s

        response.reply(rally_find_defect_by_date(field, dt1, dt2))
      end

      def rally_find_defect_range(response)
        field =
          response.matches[0][0] == 'created' ? 'CreationDate' : 'ClosedDate'
        dt1 = Time.parse(response.matches[0][1]).to_datetime.to_s
        dt2 = Time.parse(response.matches[0][2]).to_datetime.to_s

        response.reply(rally_find_defect_by_date(field, dt1, dt2))
      end

      def rally_query_raw(response)
        rally = get_rally_api

        query = RallyAPI::RallyQuery.new()
        query.type = response.matches[0][0]
        query.query_string = response.matches[0][1]

        result = rally.find(query)

        if result.count < 1
          response.reply("No object found")
        else
          response.reply(result.inject("") do |c,r|
            r.read
            "#{c}#{r['FormattedID']} - #{r['Name']}\n"
          end)
        end
      rescue Exception => e
        response.reply("Error executing query: #{e}")
      end

      def rally_mark(response)
        if config.read_only
          response.reply('Rally plugin is operating in Read-Only mode, ' \
                         'ask your chat-ops admin to disable it.')
          return
        end

        action = response.matches[0][0]
        type = response.matches[0][1].downcase
        id = response.matches[0][2]

        raise 'Only defect (DE) story (US) task (TA) are supported' unless
          %{de us ta}.include?(type)

        schedule_state = config.action_schedule_state_map[action]

        state = if type == 'ta'
                  config.action_task_state_map[action]
                else
                  config.action_state_map[action]
                end

        response.reply(
          update_object(type, id, 'ScheduleState', schedule_state)
        ) if %{de us}.include?(type)

        response.reply(update_object(type, id, 'State', state))

        update_object(type, id, 'Notes',
                      "<br />Marked #{state} by #{response.user.name} on " \
                      "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S%z')}",
                      append: true)
      rescue Exception => e
        response.reply("Error: #{e}")
      end

      def rally_show(response)
        type = response.matches[0][0].downcase
        id = response.matches[0][1]

        response.reply(get_rally_object(type, id))
      end

      def rally_release_stats(response)
        release = response.matches[0][0]
        response.reply(get_rally_release_stat(release))
      end

      def rally_release_info(response)
        release = response.matches[0][0]
        response.reply(get_rally_release_info(release))
      end

      def rally_find(response)
        type = response.matches[0][0]
        term = response.matches[0][2]
        field = response.matches[0][3]
        response.reply(rally_search(type, term, field))
      end

      private

      def get_rally_api
        @rally if instance_variable_defined?('@rally')

        rally_api_config = {
          base_url: 'https://rally1.rallydev.com/slm',
          username: config.username,
          password: config.password,
          version: config.api_version
        }

        @rally = RallyAPI::RallyRestJson.new(rally_api_config)
      end

      def validate_release(rally, release)
        query = RallyAPI::RallyQuery.new()
        query.type = 'release'
        query.query_string = "(Name = \"#{release}\")"

        rally.find(query).count > 0
      end

      def get_rally_release_info(release)
        rally = get_rally_api
        if validate_release(rally, release)
          query = RallyAPI::RallyQuery.new()
          query.type = 'defect'
          query.query_string = "(Release.Name = \"#{release}\")"

          defects = rally.find(query).map {|r| r.read['FormattedID']}.join(' ')

          query = RallyAPI::RallyQuery.new()
          query.type = 'story'
          query.query_string = "(Release.Name = \"#{release}\")"
          us = rally.find(query).map {|r| r.read['FormattedID']}.join(' ')

          "Release info for: #{release}\n" \
          "Defects: #{defects}\n" \
          "User Stories: #{us}\n"
        else
          "I can't find anything about release: '#{release}'!"
        end
      end

      def get_rally_release_stat(release)
        rally = get_rally_api
        if validate_release(rally, release)
          query = RallyAPI::RallyQuery.new()
          query.type = 'defect'
          query.query_string = "(Release.Name = \"#{release}\")"

          de_count = rally.find(query).count

          query = RallyAPI::RallyQuery.new()
          query.type = 'story'
          query.query_string = "(Release.Name = \"#{release}\")"

          us_count = rally.find(query).count

          "Release stats for: #{release}\n" \
          "Defects count: #{de_count}\n" \
          "User Story count: #{us_count}\n"
        else
          "I can find anything about release: '#{release}'!"
        end
      end

      def rally_find_defect_by_date(field, dt1, dt2)
        rally = get_rally_api

        query = RallyAPI::RallyQuery.new()
        query.type = 'defect'
        query.query_string =
          "((#{field} >= \"#{dt1}\") AND "\
          "(#{field} <= \"#{dt2}\"))"

        result = rally.find(query)

        if result.count < 1
          return "No defect found"
        else
          m_result =
            result.map do |r|
              r.read
              [r['Project'].name,r['FormattedID'], r['Name']]
            end
          m_result.sort_by {|r| r[0]}.inject("") do |c,r|
            "#{c}[#{r[0]}] #{r[1]} - #{r[2]}\n"
          end
        end
      rescue Exception => e
        "Error executing query: #{e}"
      end

      def update_object(type, id, attribute, value, options = {})
        rally = get_rally_api
        return 'Object not found' unless obj = get_by_formatted_id(type, id)

        if options[:append]
          fields = {attribute => obj.read[attribute] + value}
        else
          fields = {attribute => value}
        end

        updated = rally.update(@@key_map[type][:name],
                               "FormattedID|#{type}#{id}",
                               fields)
        "#{attribute} of #{type.upcase}#{id} has been updated to #{value}"
      rescue Exception => e
        "Exception during update: #{e}"
      end

      def get_by_formatted_id(type, id)
        rally = get_rally_api

        raise 'No such object' unless @@key_map[type]

        query = RallyAPI::RallyQuery.new()
        query.type = @@key_map[type][:name]
        query.query_string = "(FormattedID = \"#{type}#{id}\")"

        result = rally.find(query)

        raise 'No such object' if result.count < 1

        result[0]
      rescue
        nil
      end

      def get_rally_object(type, id)
        rally = get_rally_api

        if @@key_map[type]
          query = RallyAPI::RallyQuery.new()
          query.type = @@key_map[type][:name]
          query.query_string = "(FormattedID = \"#{type}#{id}\")"

          result = rally.find(query)

          if result.count < 1
            response.reply(
              "Can't find your so called #{@@key_map[type][:name]} " \
              "#{type}#{id}"
            )
          else
            out = result[0].read
            output =
              "#{link_to_item(out, type)}\n" \
              "#{out['FormattedID']} - #{out['Name'] rescue 'none'}\n" \
              "Owner: #{out['Owner']['_refObjectName'] rescue 'none'}\n" \
              "Project: #{out['Project']['_refObjectName']}\n"
            @@key_map[type][:extra_output].each do |field|
              if field.is_a?(String)
                output += "#{field}: #{out[field] rescue 'none'}\n"
              elsif field.is_a?(Array)
                output +=
                  "#{field[0]}: #{out[field[0]][field[1]] rescue 'none'}\n"
              end
            end
            output += "Description: #{strip_html(out['Description'])}\n"
          end
        else
          "I don't know the type #{type}"
        end
      end

      def link_to_item(result, type)
        project_id = result['Project']['_ref'].split('/')[-1]
        object_id = result['ObjectID']
        type_link = @@key_map[type][:link_path] || @@key_map[type][:name]
        "https://rally1.rallydev.com/#/#{project_id}/detail/#{type_link}/#{object_id}"
      end

      def strip_html(text)
        text.gsub( '<br />', "\n\n"
        ).gsub('&nbsp;', ' '
        ).gsub('&gt;', '>'
        ).gsub('&lt;', '<'
        ).gsub('<div>', ''
        ).gsub('</div>', "\n"
        ).gsub(/<style.+\/style>/, ''
        )
      end

      def rally_find_type(type, email)
        rally = get_rally_api

        q = "(Owner.EmailAddress = #{email})"
        query =
          case type
          when 'defect'
            "(#{q} AND (ScheduleState != Accepted))"
          when 'story'
            "(#{q} AND (ScheduleState != Accepted))"
          when 'task'
            "(#{q} AND (State != Completed))"
          else
            raise "Not a supported type: #{type}"
          end

        rally_search(type, query, 'raw', true)
      rescue Exception => e
        "Query error #{e}"
      end

      def rally_search(type, term, field, state = false)
        rally = get_rally_api

        query = RallyAPI::RallyQuery.new()
        if %w{defect defects}.include?(type)
          query.type = 'defect'
        elsif %w{story stories}.include?(type)
          query.type = 'story'
        else
          query.type = 'task'
        end

        if field == 'name'
          query.query_string = "(Name contains \"#{term}\")"
        elsif field == 'description'
          query.query_string = "(Description contains \"#{term}\")"
        else
          query.query_string = term
        end

        result = rally.find(query)

        return "No result found!" if result.count == 0

        result.inject("#{result.count} results total:\n") do |o,r|
          r.read
          o += "#{r['FormattedID']}"
          o += " [#{r['ScheduleState']}]" if
            state && %{defect story}.include?(type)
          o += " [#{r['State']}]" if state && type == 'task'
          o +=  " - #{r['Name']}"
          o += "\n"
        end
      end

      def get_hipchat_rest
        RestClient::Resource.new(
          "#{HIPCHAT}/",
          headers: {
            Authorization: "Bearer #{config.hipchat_token}"
          }
        )
      end

      def hipchat_find_user(mention)
        JSON.parse(
          get_hipchat_rest[
            "user/@#{mention[0] == '@' ? mention[1..-1] : mention}"
          ].get
        )['email']
      end

      def rally_find_user(email)
        rally = get_rally_api

        result =
          rally.find(
            RallyAPI::RallyQuery.new(
              {
                type: 'user',
                query_string: "(EmailAddress = #{email})"
              }
            )
          )

        return nil if result.count == 0

        result[0]
      end

    end

    Lita.register_handler(Rally)
  end
end

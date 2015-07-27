require 'rest-client'
require 'json'
require 'rally_api'

module Lita
  module Handlers
    class Rally < Handler

      RALLY = "https://rally1.rallydev.com/slm/webservice"

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

      private

      def get_rally_api
        rally_api_config = {
          base_url: 'https://rally1.rallydev.com/slm',
          username: config.username,
          password: config.password,
          version: config.api_version
        }

        RallyAPI::RallyRestJson.new(rally_api_config)
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
            output = "#{link_to_item(out, @@key_map[type][:link_path])}\n" \
                     "Owner: #{out['Owner']['_refObjectName']}\n" \
                     "Project: #{out['Project']['_refObjectName']}\n"
            @@key_map[type][:extra_output].each do |field|
              output += "#{field}: #{out[field]}\n" if
                field.is_a?(String) && out[field]
              output += "#{field[0]}: #{out[field[0]][field[1]]}\n" if
                field.is_a?(Array) && out[field[0]]
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
        "https://rally1.rallydev.com/#/#{project_id}/detail/#{type}/#{object_id}"
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

    end

    Lita.register_handler(Rally)
  end
end

require 'rest-client'
require 'json'

module Lita
  module Handlers
    class Rally < Handler
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
            ['Parent', '_refObjectName'],
            ['Feature', '_refObjectName'],
          ]
        }
      }

      config :username
      config :password
      config :api_version

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
        if config_validate
          get_rally_object(response)
        else
          response.reply('Configuration failed to validate, '\
                         'check your config')
        end
      end

      def rally_release_stats(response)
        if config_validate
          get_rally_release_stat(response)
        else
          response.reply('Configuration failed to validate, '\
                         'check your config')
        end
      end

      def rally_release_info(response)
        if config_validate
          get_rally_release_info(response)
        else
          response.reply('Configuration failed to validate, '\
                         'check your config')
        end
      end

      private

      def config_validate
        (config.username && config.password) ? true : false
      end

      def get_rest
        api_version = config.api_version ? config.api_version : 'v2.0'
        RestClient::Resource.new(
          "https://rally1.rallydev.com/slm/webservice/#{api_version}/",
          user: config.username,
          password: config.password,
        )
      end

      def validate_release(rest, release)
        query = "(Name = \"#{release}\")"
        JSON.parse(
          rest['release'].get(params: {query: query})
        )['QueryResult']['TotalResultCount'] == 0
      end

      def get_rally_release_info(response)
        rest = get_rest
        release = response.matches[0][0]
        if validate_release(rest, release)
          response.reply("I can find anything about release: '#{release}'!")
        else
          query = "(Release.Name = \"#{release}\")"
          defects = JSON.parse(
            rest['defect'].get(
              params: {
                query: query,
                fetch: 'true',
                pagesize: '200',
              }
            )
          )['QueryResult']['Results'].map {|r| r['FormattedID']}.join(' ')

          us = JSON.parse(
            rest['hierarchicalrequirement'].get(
              params: {
                query: query,
                fetch: 'true',
                pagesize: '200',
              }
            )
          )['QueryResult']['Results'].map {|r| r['FormattedID']}.join(' ')

          output = "Release info for: #{release}\n" \
                   "Defects: #{defects}\n" \
                   "User Stories: #{us}\n"
          response.reply(output)
        end
      end

      def get_rally_release_stat(response)
        rest = get_rest
        release = response.matches[0][0]
        if validate_release(rest, release)
          response.reply("I can find anything about release: '#{release}'!")
        else
          query = "(Release.Name = \"#{release}\")"
          de_result = JSON.parse(
            rest['defect'].get(params: {query: query})
          )['QueryResult']
          de_count = de_result['TotalResultCount']

          us_result = JSON.parse(
            rest['hierarchicalrequirement'].get(params: {query: query})
          )['QueryResult']
          us_count = us_result['TotalResultCount']

          output = "Release stats for: #{release}\n" \
                   "Defects count: #{de_count}\n" \
                   "User Story count: #{us_count}\n"
          response.reply(output)
        end
      end

      def get_rally_object(response)
        rest = get_rest
        type = response.matches[0][0].downcase
        id = response.matches[0][1]
        if @@key_map[type]
          query_path = (@@key_map[type][:query_path] || @@key_map[type][:name])
          link_path = (@@key_map[type][:link_path] || query_path)
          query_result = JSON.parse(
            rest[query_path].get(
              params: {
                query: "(FormattedId = #{id})",
                fetch: 'true'
              }
            )
          )['QueryResult']
          if query_result['TotalResultCount'] == 0
            response.reply("Can't find your so called #{type}#{id} in Rally!")
          else
            result = query_result['Results'][0]
            link = link_to_item(result, link_path)
            output = ''
            output += link + "\n" if link
            output += "#{result['FormattedID']} - #{result['Name']}\n" \
                      "Owner: #{result['Owner']['_refObjectName']}\n" \
                      "Project: #{result['Project']['_refObjectName']}\n"
            @@key_map[type][:extra_output].each do |field|
              output += "#{field}: #{result[field]}\n" if
                field.is_a?(String) && result[field]
              output += "#{field[0]}: #{result[field[0]][field[1]]}\n" if
                field.is_a?(Array) && result[field[0]]
            end
            output += "Description: #{strip_html(result['Description'])}\n"
            response.reply(output)
          end
        else
          response.reply("I don't know the type #{type}")
        end
      end

      def link_to_item(result, type)
        return false unless result['Project'] && result['ObjectID']
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

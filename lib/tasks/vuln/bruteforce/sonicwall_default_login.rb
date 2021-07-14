module Intrigue
  module Task
    class SonicWallDefaultLogin < BaseTask
      include Intrigue::Task::Web
      include Intrigue::Task::BruteForceLoginHelper

      def self.metadata
        {
          name: 'vuln/bruteforce/sonicwall_login_vuln',
          pretty_name: 'Bruteforce - Sonicwall Default Login Credentials',
          authors: [''],
          description: 'Bruteforce Sonicwall Default Login Credentials',
          type: 'Vuln',
          passive: false,
          allowed_types: ['Uri'],
          example_entities: [
            { 'type' => 'Uri', 'details' => { 'name' => 'http://intrigue.io' } }
          ],
          allowed_options: [
            { name: 'threads', regex: 'integer', default: 10 }
          ],
          created_types: ['Uri']
        }
      end

      def run
        super
        require_enrichment

        fingerprint = _get_entity_detail('fingerprint')

        return false unless vendor?(fingerprint, 'SonicWall') && tag?(fingerprint, 'Login Panel')

        credentials = [
          {
            user: 'admin',
            password: 'password'
          }
        ]

        task_information = {
          http_method: :get,
          uri: _get_entity_name,
          headers: {},
          data: nil,
          follow_redirects: true,
          timeout: 10,
          thread_count: _get_option('threads')
        }

        _create_entity 'Uri',
                       {
                         'name' => task_information[:uri],
                         'uri' => task_information[:uri]
                       }

        # brute with force.
        brute_force_data = bruteforce_login(task_information, credentials, method(:validator))

        unless brute_force_data[:credentials].empty?

          _log 'Creating issue'

          _create_linked_issue 'default_login_credentials',
                               {
                                 proof: {
                                   "Successful login credentials": brute_force_data[:credentials],
                                   "Responses": brute_force_data[:responses]
                                 }
                               }
        end
      end

      # custom validator, each default login task will have its own.
      # some tasks might require a more complex approach.
      def validator(response)
        !response.body_utf8.match(/id="authFrm"/i) && !response.body_utf8.match(%r{Incorrect name/password}i) && response.code.to_i.between?(
          199, 300
        )
      end
    end
  end
end
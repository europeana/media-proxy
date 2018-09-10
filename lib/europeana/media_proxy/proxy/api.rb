# frozen_string_literal: true

module Europeana
  module MediaProxy
    class Proxy
      module API
        # @!attribute [rw] permitted_api_urls
        #   @return [Array<String>] API URLs to permit in +api_url+ parameter,
        #     to which +Europeana::API.url+ is always added
        attr_accessor :permitted_api_urls

        protected

        def api_search_response(env)
          search_response = Europeana::API.record.search(api_search_params(env))

          if search_response['totalResults'].zero?
            unknown_view_msg = if env['app.params']['view'].present?
                                 %(Unknown view URL for record "#{env['app.record_id']}": "#{env['app.params']['view']}")
                               else
                                 %(Unknown record "#{env['app.record_id']}")
                               end

            fail Errors::UnknownView, unknown_view_msg
          end

          search_response
        end

        def view_url_to_proxy(env, search_response)
          requested_view = if env['app.params']['view'].present?
                             env['app.params']['view']
                           else
                             [search_response['items'].first['edmIsShownBy']].flatten.first
                           end

          if requested_view.blank?
            fail Errors::UnknownView, %(No view for record "#{env['app.record_id']}")
          end

          requested_view
        end

        # Build API search parameters for this request
        #
        # If a view parameter was specified, the search only needs to verify that
        # a record exists with the given ID and having a web resource matching
        # the view parameter, so it suffices to request the minimal profile with
        # 0 rows.
        #
        # If no view parameter was specified, then edm:isShownBy is proxied, for
        # which the rich profile is needed, and the result needs to be returned,
        # i.e. 1 row is needed.
        #
        # @return [Hash] parameters
        def api_search_params(env)
          {
            query: api_search_query(env),
            profile: env['app.params']['view'].present? ? 'minimal' : 'rich',
            api_url: env['app.params']['api_url'],
            rows: env['app.params']['view'].present? ? 0 : 1
          }
        end

        # Construct an API search query parameter for view validation
        #
        # @return [String] API search query for this request
        def api_search_query(env)
          search_query = %(europeana_id:"#{env['app.record_id']}")

          if env['app.params']['view'].present?
            search_query += %< AND (provider_aggregation_edm_isShownBy:"#{env['app.params']['view']}">
            search_query += %< OR provider_aggregation_edm_hasView:"#{env['app.params']['view']}")>
          end

          search_query
        end
      end
    end
  end
end

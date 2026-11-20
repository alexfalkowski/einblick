# frozen_string_literal: true

module Einblick
  module Site
    # Opens the same full pages and submits the same partial queries as the Logs page.
    class HTTP < Nonnative::HTTPClient
      def open(path, languages)
        get(path, options(languages))
      end

      def submit(path, form, languages)
        opts = options(languages)
        opts[:headers].merge!(content_type: 'application/x-www-form-urlencoded', hx_request: 'true')
        put(path, URI.encode_www_form(form), opts)
      end

      def submit_log_form(page, languages, preset: nil)
        document = Nokogiri::HTML5(page.body)
        form = document.at_css('#log-filters')
        filters = log_form_filters(document, form)
        if preset
          button = form.at_css("button[value='#{preset}']:not([disabled])")
          filters[button['name']] = button['value']
        end
        submit(form['hx-put'], filters, languages)
      end

      private

      def log_form_filters(document, form)
        inputs = document.css('#log-filters input[name]:not([disabled]), input[form=log-filters][name]:not([disabled])')
        filters = inputs.to_h { |input| [input['name'], input['value'].to_s] }
        form.css('select[name]:not([disabled])').each_with_object(filters) do |select, values|
          option = select.at_css('option[selected]') || select.at_css('option')
          values[select['name']] = option['value']
        end
      end

      def options(languages)
        { headers: { accept: 'text/html', accept_language: languages }, read_timeout: 10, open_timeout: 10 }
      end
    end
  end
end

# frozen_string_literal: true

module Einblick
  module Site
    # Opens the same full pages and submits the same partial queries as the Logs page.
    class HTTP < Nonnative::HTTPClient
      def open(path, languages)
        get(path, options(languages))
      end

      def load_log_assets(page)
        document = Nokogiri::HTML5(page.body)
        stylesheet = document.at_css('link[href^="/assets/logs.css"]')['href']
        script = document.at_css('script[src^="/assets/logs.js"]')['src']
        [stylesheet, script].to_h { |url| [url, get(url)] }
      end

      def submit(path, form, languages)
        opts = options(languages)
        opts[:headers].merge!(content_type: 'application/x-www-form-urlencoded', hx_request: 'true')
        put(path, URI.encode_www_form(form), opts)
      end

      def open_related_logs(page, languages)
        link = Nokogiri::HTML5.fragment(page.body).at_css('.log-timing a.related-logs')
        get(link['href'], options(languages))
      end

      def submit_log_form(page, languages, submitter: nil, layout: 'partial')
        document = Nokogiri::HTML5(page.body)
        form = document.at_css('#log-filters')
        filters = log_form_filters(document, form)
        button = log_form_button(document, form, submitter) if submitter
        filters[button['name']] = button['value'] if button&.[]('name')
        return submit_get_form(form, button, filters, languages) if layout == 'full'

        submit(form['hx-put'], filters, languages)
      end

      def open_next_page(page, languages)
        link = Nokogiri::HTML5(page.body).at_css('a.next[href]')
        get(link['href'], options(languages))
      end

      private

      def log_form_button(document, form, label)
        buttons = form.css('button[type=submit]:not([disabled]):not([form])') +
                  document.css("button[type=submit][name][form='#{form['id']}']:not([disabled])")
        buttons.find { |button| button.text == label } || raise("no enabled Logs submit button labelled #{label.inspect}")
      end

      def submit_get_form(form, button, filters, languages)
        method = button&.[]('formmethod') || form['method'] || 'get'
        raise "expected a GET form, got #{method}" unless method.casecmp?('get')

        url = URI.parse(button&.[]('formaction') || form['action'])
        url.query = URI.encode_www_form(filters)
        get(url.to_s, options(languages))
      end

      def log_form_filters(document, form)
        inputs = form.css('input[name]:not([type=submit]):not([disabled]):not([form])') +
                 document.css("input[name][form='#{form['id']}']:not([type=submit]):not([disabled])")
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

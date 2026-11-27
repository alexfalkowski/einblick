# frozen_string_literal: true

module LogView
  PRESET_VALUES = {
    'Recent' => 'recent', '15 min' => '15m', '1 hour' => '1h', '24 hours' => '24h', '3 days' => '3d', '7 days' => '7d'
  }.freeze

  LABELS = {
    'en' => {
      title: 'Logs · Einblick', heading: 'Logs', service: 'Service', submit: 'Search', reset: 'Reset', loading: 'Loading logs…',
      results: 'Log query results', message: 'Message', empty: 'No logs found',
      unavailable: 'Log storage is unavailable',
      empty_hint: 'Try a wider time range or clear a filter.', structured: 'Structured message', no_message: 'No message',
      timing: 'Timing and IDs', search: 'Search messages', time_range: 'Time range', retry: 'Try again',
      'broken link': 'This search link couldn’t be opened.', open_logs: 'Open Logs',
      related_logs: 'Find related logs', details: 'Log details', close_details: 'Close details',
      auto_refresh: 'Auto-refresh', refresh_off: 'Off',
      custom: 'Custom', activity: 'Log activity', activity_interval: '1s buckets',
      'dates out of order': 'End time must be after start time.', 'wide date range': 'This time range exceeds the search limit.',
      'invalid dates': 'Enter a valid start and end time in UTC.', 'invalid filter': 'Check the search filters and try again.',
      'outside retention': 'Choose dates within the available search period.'
    },
    'de' => {
      title: 'Protokolle · Einblick', heading: 'Protokolle', service: 'Dienst', submit: 'Suchen', reset: 'Zurücksetzen',
      loading: 'Protokolle werden geladen …', results: 'Ergebnisse der Protokollabfrage', message: 'Meldung',
      empty: 'Keine Protokolle gefunden', empty_hint: 'Wähle einen größeren Zeitraum oder entferne einen Filter.',
      unavailable: 'Der Protokollspeicher ist nicht verfügbar', structured: 'Strukturierte Meldung',
      no_message: 'Keine Meldung', timing: 'Zeitangaben und IDs',
      search: 'Meldungen durchsuchen', time_range: 'Zeitraum', retry: 'Erneut versuchen',
      'dates out of order': 'Das Ende muss nach dem Beginn liegen.', related_logs: 'Zugehörige Protokolle finden',
      details: 'Protokolldetails', close_details: 'Details schließen',
      auto_refresh: 'Automatisch aktualisieren', refresh_off: 'Aus',
      custom: 'Benutzerdefiniert', activity: 'Protokollaktivität', activity_interval: '1 s pro Balken'
    },
    'es' => {
      title: 'Registros · Einblick', heading: 'Registros', service: 'Servicio', submit: 'Buscar', reset: 'Restablecer',
      loading: 'Cargando registros…', results: 'Resultados de la consulta de registros', message: 'Mensaje',
      empty: 'No se encontraron registros', empty_hint: 'Amplía el intervalo o quita un filtro.',
      timeout: 'La consulta de registros agotó el tiempo de espera', structured: 'Mensaje estructurado',
      no_message: 'Sin mensaje', timing: 'Tiempos e identificadores',
      search: 'Buscar mensajes', time_range: 'Intervalo', retry: 'Volver a intentar',
      'broken link': 'No se pudo abrir este enlace de búsqueda.', open_logs: 'Abrir registros',
      related_logs: 'Buscar registros relacionados', details: 'Detalles del registro', close_details: 'Cerrar detalles',
      auto_refresh: 'Actualización automática', refresh_off: 'Desactivada',
      custom: 'Personalizado', activity: 'Actividad de registros', activity_interval: 'Intervalos de 1 s'
    }
  }.freeze

  def self.rows(response)
    Nokogiri::HTML5.fragment(response.body).css('#results tbody .log-row')
  end

  def self.inspector(row)
    id = row.at_css('summary')['aria-controls']
    row.next_element.at_css("##{id}")
  end

  def self.fields(section)
    section.at_css('dl').element_children.each_slice(2).to_h { |label, value| [label.text.strip, value] }
  end

  def self.timestamp(time)
    Time.iso8601(time['datetime']).to_r * 1_000_000_000
  end

  def self.query_url(response, layout)
    path = if layout == 'full'
             Nokogiri::HTML5(response.body).at_css('#results')['data-query-url']
           else
             response.headers.fetch(:hx_push_url)
           end
    URI.parse(path)
  end
end

RSpec::Matchers.define :show_log_view do |layout, language, status|
  match(notify_expectation_failures: true) do |response|
    labels = LogView::LABELS.fetch(language)
    expect(response.code).to eq(status)
    expect(response.headers[:content_type]).to eq('text/html; charset=utf-8')
    expect(response.headers[:content_language]).to eq(language)
    expect(response.headers[:vary].split(',').map { |value| value.strip.downcase }).to include('accept-language')
    expect(response.headers[:cache_control]).to eq('no-store')
    if layout == 'full'
      expect(response.headers[:einblick_view]).to be_nil
      document = Nokogiri::HTML5(response.body)
      expect(document).to show_full_log_layout(language, labels, status)
    else
      expect(response.headers[:einblick_view]).to eq('logs-results')
      document = Nokogiri::HTML5.fragment(response.body)
      expect(document.element_children.map(&:name)).to eq(['section'])
    end
    results = document.at_css('#results')
    expect(results['lang']).to eq(language)
    expect(results['aria-label']).to eq(labels.fetch(:results))
    expect(results).to show_log_results(labels) if results.at_css('table')
    true
  end
end

RSpec::Matchers.define :show_log_results do |labels|
  match(notify_expectation_failures: true) do |results|
    expect(results.css('thead th').map(&:text)).to include(labels.fetch(:message)).and have_attributes(length: 4)
    expect(results.at_css('thead th')['aria-sort']).to eq('descending')
    panel = results.at_css('dialog.log-details-panel')
    expect(panel.at_css("##{panel['aria-labelledby']}").text).to eq(labels.fetch(:details))
    expect(panel.at_css('button[type=button]')['aria-label']).to eq(labels.fetch(:close_details))
    true
  end
end

RSpec::Matchers.define :show_full_log_layout do |language, labels, status|
  match(notify_expectation_failures: true) do |document|
    expect(document.at_css('html')['lang']).to eq(language)
    expect(document.at_css('title').text).to eq(labels.fetch(:title))
    expect(document.at_css('h1').text).to eq(labels.fetch(:heading))
    expect(document.at_css('link[href^="/assets/logs.css"]')['href']).to match(%r{\A/assets/logs\.css\?v=[0-9a-f]{64}\z})
    expect(document.at_css('script[src^="/assets/logs.js"]')['src']).to match(%r{\A/assets/logs\.js\?v=[0-9a-f]{64}\z})
    if status == 200
      expect(document.at_css('label[for=service]').text).to eq(labels.fetch(:service))
      actions = document.at_css('.filters > .actions')
      expect(actions.at_css('a.btn-outline[href="/logs"]').text).to eq(labels.fetch(:reset))
      expect(actions.at_css('a + button.btn-primary[type=submit]').text).to eq(labels.fetch(:submit))
      expect(document.at_css('#query-progress[role=status]').text.strip).to eq(labels.fetch(:loading))
      expect(document.at_css('label[for=text]').text).to eq(labels.fetch(:search))
      expect(document.at_css('.filters > #time-range-label').text).to eq(labels.fetch(:time_range))
      expect(document.at_css('#custom-range').text).to eq(labels.fetch(:custom))
      expect(document.at_css('#activity-heading').text.strip).to eq(labels.fetch(:activity))
      expect(document.at_css('label[for=refresh-interval]').text).to eq(labels.fetch(:auto_refresh))
      intervals = document.css('#refresh-interval option')
      expect(intervals.map(&:text)).to eq([labels.fetch(:refresh_off), '5s', '10s', '15s'])
      expect(intervals.map { |option| option['value'] }).to eq(%w[off 5s 10s 15s])
      expect(document.at_css('#query-failure[hidden] #retry-query[type=button]').text).to eq(labels.fetch(:retry))
    end
    true
  end
end

RSpec::Matchers.define :serve_fingerprinted_log_assets do
  match(notify_expectation_failures: true) do |assets|
    expect(assets.size).to eq(2)
    assets.each do |url, response|
      uri = URI.parse(url)
      expect(response.code).to eq(200), "expected #{uri.path} to be served successfully"
      version = URI.decode_www_form(uri.query).to_h.fetch('v')
      expect(version).to eq(Digest::SHA256.hexdigest(response.body)), "expected #{uri.path} to identify its served content"
    end
  end
end

RSpec::Matchers.define :serve_png_icon do
  match(notify_expectation_failures: true) do |response|
    expect(response.code).to eq(200)
    expect(response.headers[:content_type]).to eq('image/png')
    expect(response.body.bytes.first(8)).to eq([137, 80, 78, 71, 13, 10, 26, 10])
  end
end

RSpec::Matchers.define :show_selected_logs do |service, records, receipt_windows|
  match(notify_expectation_failures: true) do |response|
    rows = LogView.rows(response)
    expect(rows.size).to eq(records.size)
    rows.zip(records).each do |row, record|
      expect(row).to show_log_entry(service, record, receipt_windows.fetch(record))
    end
  end
end

RSpec::Matchers.define :show_log_entry do |service, record, receipt_window|
  match(notify_expectation_failures: true) do |row|
    labels = LogView::LABELS.fetch(row.ancestors('#results').first['lang'])
    panel = LogView.inspector(row)
    message = record.body&.string_value
    if record.body && record.body.value != :string_value
      message = labels.fetch(:structured)
      expect(panel.at_css('.log-body-value code').text).to eq(record.body.int_value.to_s)
    end
    message = labels.fetch(:no_message) if message.to_s.strip.empty?
    expect(row.at_css('summary').text.strip).to eq(message)
    expect(panel.at_css('.log-body').text).to eq(message)
    expect(row.at_css('.service').text).to eq(service)
    expect(LogView.timestamp(row.at_css('time'))).to eq(record.time_unix_nano)
    timing = panel.at_css('.log-timing')
    expect(timing.at_css('summary').text).to eq(labels.fetch(:timing))
    timestamps = [record.time_unix_nano, record.observed_time_unix_nano].select(&:positive?)
    expect(timing).to show_exact_log_timestamps(timestamps, receipt_window)
    trace = record.trace_id.unpack1('H*')
    span = record.span_id.unpack1('H*')
    expect(timing.css('.log-id').map(&:text)).to eq([trace, span].reject(&:empty?))
    expect(timing.css('.related-logs').map(&:text)).to eq(trace.size == 32 ? [labels.fetch(:related_logs)] : [])
  end
end

RSpec::Matchers.define :show_exact_log_timestamps do |original_timestamps, receipt_window|
  match(notify_expectation_failures: true) do |timing|
    times = timing.css('time')
    expect(times.map(&:text)).to eq(times.map { |time| time['datetime'] })
    timestamps = times.map { |time| LogView.timestamp(time) }
    expect(timestamps[0...-1]).to eq(original_timestamps)
    expect(receipt_window).to cover(timestamps.last)
  end
end

RSpec::Matchers.define :show_log_time_fallbacks do |records, receipt_windows|
  match(notify_expectation_failures: true) do |response|
    expect(response.code).to eq(200)
    rows = LogView.rows(response)
    expect(rows.size).to eq(records.size)
    rows.zip(records).each do |row, record|
      expect(row).to show_log_time_fallback(record, receipt_windows.fetch(record))
    end
  end
end

RSpec::Matchers.define :show_log_time_fallback do |record, receipt_window|
  match(notify_expectation_failures: true) do |row|
    panel = LogView.inspector(row)
    expect(panel.at_css('.log-body').text).to eq(record.body.string_value)
    timing_panel = panel.at_css('.log-timing')
    observed = record.observed_time_unix_nano
    expect(timing_panel).to show_exact_log_timestamps([observed].select(&:positive?), receipt_window)
    timing = LogView.fields(timing_panel).filter_map do |label, value|
      time = value.at_css('time')
      [label, LogView.timestamp(time)] if time
    end.to_h
    receipt = timing.fetch('Received (UTC)')
    summary = panel.at_css('.log-event-fields')
    if observed.positive?
      expect(timing).to eq('Observed time (UTC)' => observed, 'Received (UTC)' => receipt)
      expect(summary.css('dt').map(&:text)).to eq(['Observed time (UTC)', 'Received'])
      expect(summary.css('dd').last.text).to show_receipt_offset((receipt - observed).fdiv(1_000_000_000), 'later')
    else
      expect(timing).to eq('Received (UTC)' => receipt)
      expect(summary.css('dt').map(&:text)).to eq(['Received (UTC)'])
    end
    selected_time = timing.fetch(summary.at_css('dt').text)
    expect(LogView.timestamp(summary.at_css('time'))).to eq(selected_time)
    expect(LogView.timestamp(row.at_css('time'))).to eq(selected_time)
  end
end

RSpec::Matchers.define :exhaust_log_search do
  match(notify_expectation_failures: true) do |response|
    expect(Nokogiri::HTML5.fragment(response.body).at_css('a.next')).to be_nil
  end
end

RSpec::Matchers.define :show_related_log_search do |filters|
  match(notify_expectation_failures: true) do |response|
    expect(response.code).to eq(200)
    page = Nokogiri::HTML5(response.body)
    expect(page.at_css('#trace-id')['value']).to eq(filters.fetch('trace_id'))
    expect(response).to preserve_log_filters(filters, 'full')
  end
end

RSpec::Matchers.define :show_log_messages do |*messages|
  match do |response|
    @actual = LogView.rows(response).map { |row| row.at_css('summary').text.strip }
    @actual == messages
  end

  failure_message do
    "expected only log messages #{messages.inspect}, got #{@actual.inspect}"
  end
end

RSpec::Matchers.define :show_log_severity do |severity|
  match(notify_expectation_failures: true) do |response|
    expect(LogView.rows(response).map { |row| row.at_css('.severity').text.split.join(' ') }).to eq([severity])
  end
end

RSpec::Matchers.define :preserve_log_filters do |filters, layout = 'partial'|
  match(notify_expectation_failures: true) do |response|
    path = LogView.query_url(response, layout)
    expect(path.path).to eq('/logs')
    expect(URI.decode_www_form(path.query).to_h).to eq(filters.except('start_time', 'end_time').merge('window' => '1h'))
    results = Nokogiri::HTML5.fragment(response.body).at_css('#results')
    expect(results['data-start-time']).to eq(filters.fetch('start_time'))
    expect(results['data-end-time']).to eq(filters.fetch('end_time'))
  end
end

RSpec::Matchers.define :show_literal_log do |service, message, term|
  match(notify_expectation_failures: true) do |response|
    expect(response.code).to eq(200)
    document = Nokogiri::HTML5.fragment(response.body)
    expect(document.css('#results script, #results img, #results b')).to be_empty
    row = document.at_css('tbody .log-row')
    expect(row.at_css('summary')).to show_message_match(term)
    expect(row.at_css('.service').text).to eq(service)
    expect(row.at_css('.severity').text).to include('100')
    panel = LogView.inspector(row)
    expect(panel.css('pre')).to be_empty
    expect(panel.at_css('.log-body').text).to eq(message)
    expect(panel).to show_http_log_summary
    attributes = LogView.fields(panel.at_css('.log-attributes'))
    expect(attributes.fetch('request.id').text).to eq('<img src=x>attribute')
    expect(attributes.fetch('large_integer').text).to eq('9007199254740993')
    nested = attributes.fetch('nested')
    expect(nested.css('details > summary').map(&:text)).to eq(['Key-value pairs (1)', 'List (3)'])
    expect(nested.css('ol .log-value-text').map(&:text)).to eq(['true', '1.25', 'AP8='])
    source = panel.at_css('.log-source')
    expect(source.at_css('dt[title="service.name"] + dd').text).to eq(service)
    expect(source.at_css('dt[title="service.version"] + dd').text).to eq('0.0.0')
    expect(LogView.fields(source).fetch('Schema URL').text).to eq('https://opentelemetry.io/schemas/1.43.0')
    expect(source.at_css('.log-scope dd').text).to eq('e01-client')
  end
end

RSpec::Matchers.define :show_message_match do |term|
  match(notify_expectation_failures: true) do |summary|
    expect(summary.css('mark').map(&:text)).to eq([term])
    expect(summary.text.strip).to start_with('…ɸ').and end_with('é…')
  end
end

RSpec::Matchers.define :show_empty_message_search do |term|
  match(notify_expectation_failures: true) do |response|
    expect(response.code).to eq(200)
    document = Nokogiri::HTML5(response.body)
    empty = document.at_css('#results .empty-state')
    expect(empty.at_css('h2').text).to eq("No messages match “#{term}”")
    expect(empty.css('img')).to be_empty
    expect(empty.at_css('button[form=log-filters][name=clear_message]').text).to eq('Clear search')
    expect(document.at_css('#clear-message:not([hidden])')['aria-label']).to eq('Clear search')
  end
end

RSpec::Matchers.define :show_http_log_summary do
  match(notify_expectation_failures: true) do |panel|
    expect(panel.at_css('.log-environment').text).to eq('development')
    summary = panel.css('.log-summary-fields > div').to_h { |field| [field.at_css('dt').text, field.at_css('dd').text] }
    expect(panel).to show_request_summary('HTTP status', '200', '235.06 ms')
    event, received = panel.css('.log-timing time').to_a.values_at(0, -1).map { |time| LogView.timestamp(time) }
    direction = received > event ? 'later' : 'earlier'
    expect(summary.fetch('Received')).to show_receipt_offset((received - event).abs / 1_000_000_000, direction)
  end
end

RSpec::Matchers.define :show_log_request do |label, status, duration|
  match(notify_expectation_failures: true) do |response|
    expect(response.code).to eq(200)
    rows = LogView.rows(response)
    expect(rows.size).to eq(1)
    expect(LogView.inspector(rows.first)).to show_request_summary(label, status, duration)
  end
end

RSpec::Matchers.define :show_request_summary do |label, status, duration|
  match(notify_expectation_failures: true) do |panel|
    fields = panel.css('.log-request-fields > div').to_h { |field| [field.at_css('dt').text, field.at_css('dd').text] }
    expect(fields).to eq(label => status, 'Request duration' => duration)
  end
end

RSpec::Matchers.define :show_receipt_offset do |seconds, direction|
  match(notify_expectation_failures: true) do |offset|
    if seconds < 0.001
      expect(offset).to eq("<1 ms #{direction}")
    else
      amount, unit, shown_direction = offset.split
      unit_seconds = { 'ms' => 0.001, 's' => 1, 'min' => 60, 'h' => 3600, 'd' => 86_400 }.fetch(unit)
      expect(shown_direction).to eq(direction)
      expect(amount.to_i * unit_seconds).to be_within(unit_seconds / 2.0).of(seconds)
    end
  end
end

RSpec::Matchers.define :show_blank_log_details do |label, messages|
  match(notify_expectation_failures: true) do |response|
    expect(response.code).to eq(200)
    rows = LogView.rows(response)
    expect(rows.map { |row| row.at_css('details > summary').text.strip }).to eq([label] * messages.size)
    expect(rows.map { |row| LogView.inspector(row).at_css('.log-body-value code').text }).to eq(messages)
    expect(rows.map { |row| LogView.inspector(row).at_css('.log-body-value .log-value-label').text }).to all(eq('Leere Zeichenfolge'))
  end
end

RSpec::Matchers.define :show_log_pages do |service, records, receipt_windows, sizes|
  match(notify_expectation_failures: true) do |responses|
    expect(responses.map(&:code)).to eq([200] * sizes.size)
    rows = responses.map { |response| LogView.rows(response) }
    expect(rows.map(&:size)).to eq(sizes)
    rows.flatten.zip(records).each do |row, record|
      expect(row).to show_log_entry(service, record, receipt_windows.fetch(record))
    end
    expect(responses.last).to exhaust_log_search
  end
end

RSpec::Matchers.define :continue_full_page_log_search do |first_message, next_message|
  match(notify_expectation_failures: true) do |responses|
    first, next_page = responses
    expect(first).to show_log_view('full', 'en', 200).and show_log_messages(first_message)
    expect(next_page).to show_log_view('full', 'en', 200).and show_log_messages(next_message).and exhaust_log_search
    expect(LogView.query_url(next_page, 'full')).to eq(LogView.query_url(first, 'full'))
    expect(next_page).to keep_log_time_bounds(first)
  end
end

RSpec::Matchers.define :show_log_outcome do |outcome, language|
  match(notify_expectation_failures: true) do |response|
    labels = LogView::LABELS.fetch(language)
    document = Nokogiri::HTML5.fragment(response.body)
    results = document.at_css('#results')
    expect(results.css('table')).to be_empty
    expect(results.css('time')).to be_empty
    if outcome == 'empty'
      expect(results.at_css('.empty-state h2').text).to eq(labels.fetch(:empty))
      expect(results.at_css('.empty-state p').text).to eq(labels.fetch(:empty_hint))
    else
      expect(results).to show_log_alert(outcome, labels, document.at_css('main'))
    end
    expect(results.text).not_to match(/query error|catalog error|unavailable_logs|select l\.id/i)
  end
end

RSpec::Matchers.define :show_log_alert do |outcome, labels, full|
  match(notify_expectation_failures: true) do |results|
    alert = results.at_css('[role=alert]')
    expect(alert.at_css('p').text).to start_with(labels.fetch(outcome.to_sym))
    if full || outcome == 'broken link'
      expect(alert.at_css('a[href="/logs"]').text).to eq(labels.fetch(:open_logs))
    else
      expect(alert.css('a')).to be_empty
    end
    true
  end
end

RSpec::Matchers.define :show_time_and_severity_controls do
  match(notify_expectation_failures: true) do |response|
    document = Nokogiri::HTML5(response.body)
    presets = document.at_css('.filters > .time-presets[aria-labelledby=time-range-label]')
    expect(presets.css('button').map(&:text)).to eq(['15 min', '1 hour', '24 hours', '3 days', '7 days', 'Custom'])
    expect(presets.css('button[aria-pressed=true]').map(&:text)).to eq(['1 hour'])
    expect(document.css('#custom-dates[hidden] input[type=datetime-local][disabled]').length).to eq(2)
    expect(document.css('#log-filters .actions button[type=submit]').map(&:text)).to eq(['Search'])
    expect(document.at_css('#results')['data-activity-url']).to start_with('/logs/activity?')
    expect(document.css('#log-activity button')).to be_empty
    expect(document.at_css('#activity-heading > #activity-interval').text).to be_empty
    expect(document.at_css('#log-result-total[hidden] + #results')).not_to be_nil
    expect(document.css('#severity option').map(&:text)).to eq(['All severities', 'Debug', 'Info', 'Warn', 'Error', 'Fatal'])
  end
end

RSpec::Matchers.define :show_only_selected_preset do |preset|
  match(notify_expectation_failures: true) do |response|
    expect(response.code).to eq(200)
    buttons = Nokogiri::HTML5(response.body).css('.time-presets button[name=window]')
    expect(buttons.map { |button| [button.text, button['aria-pressed']] }).to eq([[preset, 'true']])
  end
end

RSpec::Matchers.define :preserve_recent_window do |preset, seconds, expected_end, filters = {}, layout = 'partial'|
  match(notify_expectation_failures: true) do |response|
    expect(response.code).to eq(200)
    url = LogView.query_url(response, layout)
    expect(url.path).to eq('/logs')
    query = URI.decode_www_form(url.query).to_h
    window = LogView::PRESET_VALUES.fetch(preset)
    expect(query).to eq(filters.merge('window' => window))
    results = Nokogiri::HTML5.fragment(response.body).at_css('#results')
    ending = Time.iso8601(results['data-end-time'])
    beginning = Time.iso8601(results['data-start-time'])
    expect(ending.to_r - beginning.to_r).to eq(seconds)
    expect(expected_end).to cover(ending)
    expect(results['data-window']).to eq(window)
  end
end

RSpec::Matchers.define :keep_log_time_bounds do |before|
  match(notify_expectation_failures: true) do |response|
    expect(response.code).to eq(200)
    original = Nokogiri::HTML5(before.body).at_css('#results')
    actual = Nokogiri::HTML5(response.body).at_css('#results')
    expect(actual['data-start-time']).to eq(original['data-start-time'])
    expect(actual['data-end-time']).to eq(original['data-end-time'])
  end
end

RSpec::Matchers.define :offer_default_log_reload do
  match(notify_expectation_failures: true) do |response|
    query = LogView.query_url(response, 'full').query
    expect(URI.decode_www_form(query).to_h).to include('window' => '1h')
  end
end

RSpec::Matchers.define :offer_log_search_window do |window|
  match(notify_expectation_failures: true) do |response|
    query = URI.decode_www_form(LogView.query_url(response, 'full').query).to_h
    expect(query['window']).to eq(window)
    doc = Nokogiri::HTML5(response.body)
    expect(doc.css('#log-filters [data-search-submit]').map { |button| button['value'] }).to eq([window, window])
    true
  end
end

RSpec::Matchers.define :show_saved_time_range do |bounds|
  match(notify_expectation_failures: true) do |response|
    expect(response.code).to eq(200)
    document = Nokogiri::HTML5(response.body)
    results = document.at_css('#results')
    expect(results['data-start-time']).to eq(bounds.fetch('start_time'))
    expect(results['data-end-time']).to eq(bounds.fetch('end_time'))
    expect(document.at_css('#current-range:not([hidden])').text).to eq('Current range')
    expect(document.css('.time-presets button[aria-pressed=true]')).to be_empty
  end
end

RSpec::Matchers.define :show_custom_log_range do |bounds|
  match(notify_expectation_failures: true) do |response|
    expect(response.code).to eq(200)
    doc = Nokogiri::HTML5(response.body)
    expect(doc.at_css('#custom-range')['aria-expanded']).to eq('true')
    dates = doc.at_css('#custom-dates:not([hidden])')
    expect(dates.css('input[required]:not([disabled])').map { |date| date['aria-label'] }).to eq(['From (UTC)', 'To (UTC)'])
    expect(dates.css('label')).to be_empty
    expect(dates.css('input[min], input[max]')).to be_empty
    results = doc.at_css('#results')
    expect(results['data-start-time']).to eq(bounds.fetch('start_time'))
    expect(results['data-end-time']).to eq(bounds.fetch('end_time'))
    url = LogView.query_url(response, 'full')
    expect(URI.decode_www_form(url.query).to_h).to include(bounds.merge('custom' => '1'))
    true
  end
end

RSpec::Matchers.define :show_activity_error do |status, outcome|
  match(notify_expectation_failures: true) do |response|
    expect(response.code).to eq(status)
    expect(response.headers).to include(einblick_view: 'logs-activity', cache_control: 'no-store')
    expect(response).to show_log_outcome(outcome, 'en')
    true
  end
end

RSpec::Matchers.define :show_localized_log_activity do |language|
  match(notify_expectation_failures: true) do |response|
    labels = LogView::LABELS.fetch(language)
    expect(response.code).to eq(200)
    expect(response.headers).to include(content_type: 'text/html; charset=utf-8', content_language: language,
                                        cache_control: 'no-store', einblick_view: 'logs-activity')
    expect(response.headers[:vary].split(',').map { |value| value.strip.downcase }).to include('accept-language')
    doc = Nokogiri::HTML5.fragment(response.body)
    summary = doc.at_css('.activity-summary')
    expect(summary['lang']).to eq(language)
    expect(summary['data-interval-label']).to eq(labels.fetch(:activity_interval))
    expect(doc.at_css('.activity-tooltip')['data-search']).to eq(labels.fetch(:submit))
    true
  end
end

RSpec::Matchers.define :show_activity_counts do |counts, page|
  match(notify_expectation_failures: true) do |response|
    expect(response.code).to eq(200)
    doc = Nokogiri::HTML5.fragment(response.body)
    matches = counts.sum == 1 ? '1 matching log' : "#{counts.sum} matching logs"
    total_label = "#{matches} when activity loaded"
    summary = doc.at_css('.activity-summary')
    expect(summary['data-total-label']).to eq(total_label)
    expect(summary.text).not_to include(total_label)
    bars = doc.css('.activity-bar')
    expect(bars.map { |bar| bar['data-count'].to_i }).to eq(counts)
    results = Nokogiri::HTML5(page.body).at_css('#results')
    expect(bars.first['data-start']).to eq(results['data-start-time'])
    expect(bars.last['data-end']).to eq(results['data-end-time'])
    expect(bars.each_cons(2).map { |left, right| left['data-end'] == right['data-start'] }).to all(be(true))
    true
  end
end

RSpec::Matchers.define :link_to_first_activity_bucket do |page, bounds|
  match(notify_expectation_failures: true) do |response|
    document = Nokogiri::HTML5.fragment(response.body)
    results = Nokogiri::HTML5(page.body).at_css('#results')
    expect(bounds.fetch('start_time')).to eq(results['data-start-time'])
    link = URI.parse(document.at_css('.activity-intervals a')['href'])
    expect(link.path).to eq('/logs')
    expect(URI.decode_www_form(link.query).to_h).to include(bounds.merge('custom' => '1'))
    true
  end
end

RSpec::Matchers.define :show_clipped_activity_labels do
  match(notify_expectation_failures: true) do |response|
    expect(response.code).to eq(200)
    document = Nokogiri::HTML5.fragment(response.body)
    bucket = document.css('.activity-bar').last
    expect(bucket['data-start-label']).to eq('11:00:00')
    expect(bucket['data-end-label']).to eq('11:00:42.123456789')
    expect(bucket['data-summary']).to include('11:00:00 – 11:00:42.123456789 UTC')
    expect(document.css('.activity-axis time').last.text).to end_with('11:00 UTC')
    true
  end
end

RSpec::Matchers.define :show_log_lookback do |seconds, searched_at|
  match(notify_expectation_failures: true) do |response|
    expect(response.code).to eq(200)
    doc = Nokogiri::HTML5(response.body)
    label = doc.at_css('#custom-dates:not([hidden]) #earliest-date:not([hidden]) time')
    earliest = Time.iso8601(label['datetime'])
    expect(searched_at).to cover(earliest + seconds)
    expect(label.text).to eq(earliest.strftime('%F %T'))
    true
  end
end

RSpec::Matchers.define :show_activity_times_for do |event_time|
  match(notify_expectation_failures: true) do |response|
    document = Nokogiri::HTML5.fragment(response.body)
    expect(document.at_css('.activity-summary')['data-interval-label']).to eq('1s buckets')
    start = Time.iso8601(event_time).floor
    bucket = document.at_css(%(.activity-bar[data-start="#{start.iso8601}"]))
    expect(bucket['data-start']).to eq(start.iso8601)
    expect(bucket['data-end']).to eq((start + 1).iso8601)
    expect(bucket['data-summary']).to include(start.strftime('%H:%M:%S'), (start + 1).strftime('%H:%M:%S'))
    intervals = document.at_css('details.activity-intervals')
    expect(intervals.at_css('summary').text).to eq('Browse activity intervals')
    link = intervals.css('a[href]').find { |item| item.text.start_with?(start.iso8601) }
    expect(link.text).to include(start.iso8601, (start + 1).iso8601)
    url = URI.parse(link['href'])
    expect(url.path).to eq('/logs')
    bounds = { 'start_time' => start.iso8601, 'end_time' => (start + 1).iso8601 }
    expect(URI.decode_www_form(url.query).to_h).to include(bounds.merge('custom' => '1', 'text' => 'bucket boundary'))
    ticks = document.css('.activity-axis time')
    expect(ticks.map { |tick| tick['datetime'] }).to include(start.iso8601)
    expect(document.at_css('.activity-tooltip[hidden][data-search="Search"]').text).to be_empty
    expect(ticks.map(&:text).grep(/UTC/)).to eq([ticks.last.text])
    expect(document.at_css('.activity-summary')['data-through-label']).to eq("Chart through #{ticks.last.text}")
    true
  end
end

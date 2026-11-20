# frozen_string_literal: true

module LogView
  LABELS = {
    'en' => {
      title: 'Logs · Einblick', heading: 'Logs', service: 'Service', submit: 'Query logs', loading: 'Loading logs…',
      results: 'Log query results', message: 'Message', empty: 'No logs match these filters',
      invalid: 'Invalid log query'
    },
    'de' => {
      title: 'Protokolle · Einblick', heading: 'Protokolle', service: 'Dienst', submit: 'Protokolle abfragen',
      loading: 'Protokolle werden geladen …', results: 'Ergebnisse der Protokollabfrage', message: 'Meldung',
      empty: 'Im gewählten Zeitraum gibt es keine Protokolle', invalid: 'Ungültige Protokollabfrage',
      unavailable: 'Der lokale Protokollspeicher ist nicht verfügbar'
    },
    'es' => {
      title: 'Registros · Einblick', heading: 'Registros', service: 'Servicio', submit: 'Consultar registros',
      loading: 'Cargando registros…', results: 'Resultados de la consulta de registros', message: 'Mensaje',
      empty: 'No hay registros que coincidan', invalid: 'Consulta de registros no válida',
      timeout: 'La consulta de registros agotó el tiempo de espera'
    }
  }.freeze

  def self.rows(response)
    Nokogiri::HTML5.fragment(response.body).css('#results tbody tr')
  end

  def self.record(row)
    Opentelemetry::Proto::Logs::V1::LogRecord.decode_json(row.at_css('.record').text)
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
    expect(results.css('th').map(&:text)).to include(labels.fetch(:message)) if results.at_css('table')
    true
  end
end

RSpec::Matchers.define :show_full_log_layout do |language, labels, status|
  match(notify_expectation_failures: true) do |document|
    expect(document.at_css('html')['lang']).to eq(language)
    expect(document.at_css('title').text).to eq(labels.fetch(:title))
    expect(document.at_css('h1').text).to eq(labels.fetch(:heading))
    if status == 200
      expect(document.at_css('label[for=service]').text).to eq(labels.fetch(:service))
      expect(document.at_css('button[type=submit]').text).to eq(labels.fetch(:submit))
      expect(document.at_css('#query-progress[role=status]').text.strip).to eq(labels.fetch(:loading))
    end
    true
  end
end

RSpec::Matchers.define :show_selected_logs do |service, records|
  match(notify_expectation_failures: true) do |response|
    rows = LogView.rows(response)
    expect(rows.map { |row| LogView.record(row) }).to eq(records)
    expect(rows.map { |row| row.at_css('.service').text }.uniq).to eq([service])
    expect(rows.map { |row| Time.iso8601(row.at_css('time')['datetime']).to_r * 1_000_000_000 }).to eq(records.map(&:time_unix_nano))
    traces = records.map { |record| record.trace_id.empty? ? '—' : record.trace_id.unpack1('H*') }
    expect(rows.map { |row| row.at_css('.trace').text }).to eq(traces)
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

RSpec::Matchers.define :preserve_log_filters do |filters|
  match do |response|
    @path = URI.parse(response.headers.fetch(:hx_push_url))
    @path.path == '/logs' && URI.decode_www_form(@path.query).to_h == filters
  end

  failure_message do
    "expected query filters #{filters.inspect} in #{@path}"
  end
end

RSpec::Matchers.define :show_literal_log do |service|
  match(notify_expectation_failures: true) do |response|
    expect(response.code).to eq(200)
    document = Nokogiri::HTML5.fragment(response.body)
    expect(document.css('#results script, #results img, #results b')).to be_empty
    row = document.at_css('tbody tr')
    expect(row.at_css('summary').text.strip).to eq('<script>telemetry</script><b>message</b>')
    expect(row.at_css('.service').text).to eq(service)
    expect(row.at_css('.severity').text).to include('100')
    record = LogView.record(row)
    expect(record.attributes.first.value.string_value).to eq('<img src=x>attribute')
    expect(record.attributes.find { |attribute| attribute.key == 'large_integer' }.value.int_value).to eq(9_007_199_254_740_993)
    expect(JSON.parse(row.at_css('.resource').text).fetch('resource').fetch('attributes')).to include(
      'key' => 'service.name', 'value' => { 'stringValue' => service }
    )
    expect(JSON.parse(row.at_css('.instrumentation').text).dig('scope', 'name')).to eq('e01-client')
  end
end

RSpec::Matchers.define :show_blank_log_details do |label, messages|
  match(notify_expectation_failures: true) do |response|
    expect(response.code).to eq(200)
    rows = LogView.rows(response)
    expect(rows.map { |row| row.at_css('details > summary').text.strip }).to eq([label] * messages.size)
    expect(rows.map { |row| LogView.record(row).body.string_value }).to eq(messages)
  end
end

RSpec::Matchers.define :show_log_pages do |service, records, sizes|
  match(notify_expectation_failures: true) do |responses|
    expect(responses.map(&:code)).to eq([200] * sizes.size)
    rows = responses.map { |response| LogView.rows(response) }
    expect(rows.map(&:size)).to eq(sizes)
    expect(rows.flatten.map { |row| LogView.record(row) }).to eq(records)
    expect(rows.flatten.map { |row| row.at_css('.service').text }.uniq).to eq([service])
    expect(Nokogiri::HTML5.fragment(responses.last.body).at_css('a.next')).to be_nil
  end
end

RSpec::Matchers.define :show_log_outcome do |outcome, language|
  match(notify_expectation_failures: true) do |response|
    label = LogView::LABELS.fetch(language).fetch(outcome.to_sym)
    results = Nokogiri::HTML5.fragment(response.body).at_css('#results')
    expect(results.css('table')).to be_empty
    notice = outcome == 'empty' ? '.notice' : '[role=alert]'
    expect(results.at_css(notice).text).to include(label)
    expect(results.text).not_to match(/query error|catalog error|unavailable_logs|select l\.id/i)
  end
end

RSpec::Matchers.define :show_time_and_severity_controls do
  match(notify_expectation_failures: true) do |response|
    document = Nokogiri::HTML5(response.body)
    expect(document.css('.time-presets button').map(&:text)).to eq(['Last 15 minutes', 'Last hour', 'Last 24 hours'])
    expect(document.css('input[type=datetime-local]').map { |input| input['name'] }).to eq(%w[start_utc end_utc])
    expect(document.css('#severity option').map(&:text)).to eq(['All severities', 'Debug', 'Info', 'Warn', 'Error', 'Fatal'])
  end
end

RSpec::Matchers.define :preserve_recent_window do |duration, expected_end, service|
  match(notify_expectation_failures: true) do |response|
    expect(response.code).to eq(200)
    query = URI.decode_www_form(URI.parse(response.headers.fetch(:hx_push_url)).query).to_h
    expect(query.keys).to contain_exactly('start_time', 'end_time', 'service')
    expect(query.fetch('service')).to eq(service)
    ending = Time.iso8601(query.fetch('end_time'))
    beginning = Time.iso8601(query.fetch('start_time'))
    expect(ending.to_r - beginning.to_r).to eq(duration)
    expect(expected_end).to cover(ending)
  end
end

RSpec::Matchers.define :show_time_range do |*bounds|
  match(notify_expectation_failures: true) do |response|
    range = Nokogiri::HTML5.fragment(response.body).at_css('.time-range')
    expect(range.css('time').map(&:text)).to eq(bounds)
    expect(range.text.strip).to end_with('UTC')
  end
end

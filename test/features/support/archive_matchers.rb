# frozen_string_literal: true

RSpec::Matchers.define :complete_archive_batch_before_retry do |operation, healthy_id, blocked_id|
  match(notify_expectation_failures: true) do |diagnostics|
    completed = diagnostics.index(/#{Regexp.escape(operation)} completed.*batch_id=#{Regexp.escape(healthy_id)}/)
    retried = diagnostics.index(/#{Regexp.escape(operation)} failed.*batch_id=#{Regexp.escape(blocked_id)}/)
    expect(completed).not_to be_nil
    expect(retried).not_to be_nil
    expect(completed).to be < retried
  end
end

RSpec::Matchers.define :omit_archive_backlog_gauges do
  match(notify_expectation_failures: true) do |response|
    expect(response.code).to eq(200)
    expect(response.body).to have_duckdb_metric('einblick_db_sql_connection_open')
    expect(response.body).not_to match(/^einblick_log_archive_(?:pending_|last_publication_)/)
  end
end

# Extracts read intervals from the sampler's timeout diagnostics.
module BacklogReadWindows
  def self.from(diagnostics)
    pattern = /^time=(\S+).*log archive backlog collection failed.*started_at=(\S+).*context deadline exceeded/
    diagnostics.scan(pattern).map do |finished, started|
      Time.iso8601(started)..Time.iso8601(finished)
    end
  end
end

RSpec::Matchers.define :have_backlog_refresh_failures do |count, interval: nil|
  match(notify_expectation_failures: true) do |diagnostics|
    reads = BacklogReadWindows.from(diagnostics)
    expect(reads.size).to be >= count
    next true unless interval

    first_duration = reads.first.end - reads.first.begin
    expect(first_duration).to be > interval
    # The text logger records completion times to millisecond precision.
    expect(reads[1].begin - reads.first.end).to be >= first_duration - 0.002
  end
end

RSpec::Matchers.define :have_cached_backlog_during_first_read do |diagnostics, pending_records|
  match(notify_expectation_failures: true) do |scrapes|
    first_read = BacklogReadWindows.from(diagnostics).fetch(0)
    metrics = scrapes.filter_map do |started, finished, response|
      response.body if response.code == 200 && first_read.cover?(started) && first_read.cover?(finished)
    end
    expect(metrics).to include(
      have_duckdb_metric('einblick_db_sql_connection_open').and(have_archive_backlog('pending_records' => pending_records))
    )
  end
end

RSpec::Matchers.define :label_log_coverage do |label, empty: false|
  match(notify_expectation_failures: true) do |response|
    fragment = Nokogiri::HTML5.fragment(response.body)
    expect(fragment.at_css('#results .result-coverage')&.text).to eq(label)
    if empty
      expect(fragment.at_css('#results .empty-state')).not_to be_nil
    else
      expect(fragment.css('#results .log-row')).not_to be_empty
    end
  end
end

RSpec::Matchers.define :have_archive_backlog do |expected|
  match(notify_expectation_failures: true) do |metrics|
    gauges = metrics.scan(/^einblick_log_archive_(\w+)(?:\{[^\n]*\})? (\S+)/).to_h
    expect(gauges.transform_values { |value| Float(value) }).to include(expected)
  end
end

RSpec::Matchers.define :retain_archive_members do |batch, logs|
  match(notify_expectation_failures: true) do |members|
    expect(members).to match_array(logs.map { |row| [row.first, batch] })
  end
end

RSpec::Matchers.define :include_both_archive_copies do |expected_count|
  match(notify_expectation_failures: true) do |logs|
    copies_by_id = logs.group_by(&:id)
    expect(copies_by_id.size).to eq(expected_count)
    expect(copies_by_id.values.map(&:size)).to all(eq(2))
  end
end

RSpec::Matchers.define :retain_staging_with_publication_status do |published|
  match(notify_expectation_failures: true) do |snapshot|
    expect(snapshot.fetch(:batches).size).to eq(1)
    id, _, _, staged_checksum, published_checksum, confirmed, cleaned = snapshot.fetch(:batches).first
    expect(snapshot.fetch(:files)).to eq(id => staged_checksum)
    expect(staged_checksum).not_to be_nil
    expect(confirmed).to eq(published)
    expect(published_checksum).to eq(published ? staged_checksum : nil)
    expect(cleaned).to be(false)
  end
end

RSpec::Matchers.define :retain_pending_corrupt_staging do |remote_checksum|
  match(notify_expectation_failures: true) do |snapshot|
    expect(snapshot.fetch(:batches).size).to eq(1)
    id, _, _, staged, published, confirmed, cleaned = snapshot.fetch(:batches).first
    expect(snapshot.fetch(:files).keys).to eq([id])
    expect(snapshot.fetch(:files).fetch(id)).not_to eq(remote_checksum)
    expect([staged, published, confirmed, cleaned]).to eq([nil, remote_checksum, true, false])
  end
end

RSpec::Matchers.define :retain_only_earlier_staging do |earlier_key, later_key, checksums, earlier_confirmed|
  match(notify_expectation_failures: true) do |snapshot|
    earlier = File.basename(earlier_key, '.parquet')
    later = File.basename(later_key, '.parquet')
    expect(snapshot.fetch(:files)).to eq(earlier => checksums.fetch(earlier))
    state_by_id = snapshot.fetch(:batches).to_h { |row| [row.first, row.drop(3)] }
    earlier_checksum = checksums.fetch(earlier)
    expect(state_by_id).to eq(
      earlier => [earlier_checksum, earlier_confirmed ? earlier_checksum : nil, earlier_confirmed, false],
      later => [nil, checksums.fetch(later), true, true]
    )
  end
end

RSpec::Matchers.define :match_archive_key_checksums do |checksums, *keys|
  match do |objects|
    objects == keys.to_h { |key| [key, checksums.fetch(File.basename(key, '.parquet'))] }
  end
end

RSpec::Matchers.define :contain_partitioned_log_days do |*expected_days|
  match do |partitions|
    @days = partitions.keys.map { |path| File.basename(File.dirname(path)).delete_prefix('day=') }
    @days.sort == expected_days.sort && partitions.all? do |path, event_times|
      day = File.basename(File.dirname(path)).delete_prefix('day=')
      event_times.any? && event_times.all? { |ns| Time.at(ns / 1_000_000_000).utc.strftime('%F') == day }
    end
  end

  failure_message do
    "expected one Parquet partition for each of #{expected_days}, with every event in its UTC day, got #{@days}"
  end
end

RSpec::Matchers.define :match_durable_archive_batches do |batches, members, checksums, workspace|
  match do |file_members|
    grouped = members.group_by(&:last)
    @expected_files = batches.to_h do |id, day, _digest, checksum|
      path = File.join(workspace, 'v1', 'signal=logs', "day=#{day}", "#{id}.parquet")
      [path, [grouped.fetch(id, []).map(&:first).sort, checksum]]
    end
    @actual_files = file_members.to_h { |path, ids| [path, [ids, checksums.fetch(path)]] }
    @actual_files == @expected_files
  end

  failure_message do
    "expected staged Parquet paths, log IDs and checksums to match durable state: #{@expected_files}; got #{@actual_files}"
  end
end

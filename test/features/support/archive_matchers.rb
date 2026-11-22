# frozen_string_literal: true

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

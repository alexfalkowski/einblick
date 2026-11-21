# frozen_string_literal: true

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

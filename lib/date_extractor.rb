require "date"
require "date_extractor/version"

module DateExtractor
  RANGE_RE = /
    [-~〜～ー]
  /x

  NUMBER_RE = /
    (?:\d+)|(?:[０-９]+)
  /x

  # NOTE: Use `(?!間)` to reject `"〜時間"`
  START_CHINESE_CHARACTER_TIME_RE = /
    (?<start_hour>#{NUMBER_RE})時(?!間)
    (?:
      (?<start_min>#{NUMBER_RE}分)
      |
      (?<start_half_hour_unit>半)
    )?
  /x
  END_CHINESE_CHARACTER_TIME_RE = /
    (?<end_hour>#{NUMBER_RE})時(?!間)
    (?:
      (?<end_min>#{NUMBER_RE}分)
      |
      (?<end_half_hour_unit>半)
    )?
  /x

  TIMESLOT_RE1 = /
    (?<start_hour>#{NUMBER_RE}+)[:;](?<start_min>#{NUMBER_RE})
    \s*
    #{RANGE_RE}?
    \s*
    (?:
      (?<end_hour>#{NUMBER_RE})[:;](?<end_min>#{NUMBER_RE})
    )?
  /x

  TIMESLOT_RE2 = /
    #{START_CHINESE_CHARACTER_TIME_RE}以降
  /x

  TIMESLOT_RE3 = /
    #{START_CHINESE_CHARACTER_TIME_RE}
    \s*
    #{RANGE_RE}?
    \s*
    (?:#{END_CHINESE_CHARACTER_TIME_RE})?
  /x

  TIMESLOT_RE4 = /
    (?:朝)?
      #{RANGE_RE}
      \s*
      (?:
        (?<end_hour>#{NUMBER_RE})[:;](?<end_min>#{NUMBER_RE})
      )
  /x

  TIMESLOT_RE = /
    (?:#{TIMESLOT_RE1})|(?:#{TIMESLOT_RE2})|(?:#{TIMESLOT_RE3}|(?:#{TIMESLOT_RE4}))
  /x

  WDAY_RE = /
    (?:
      \([^()]+\)
    )
    |
    (?:
     （[^（）]+）
    )
  /x

  DAY_RE1 = /
    (?<year>#{NUMBER_RE})\/(?<month>#{NUMBER_RE})\/(?<day>#{NUMBER_RE})
      \s*
      (?:#{WDAY_RE})?
      \s*
      (?:#{TIMESLOT_RE})?
  /x

  DAY_RE2 = /
    (?<month>#{NUMBER_RE})\/(?<day>#{NUMBER_RE})
      \s*
      (?:#{WDAY_RE})?
      \s*
      (?:#{TIMESLOT_RE})?
  /x

  DAY_RE3 = /
    (?<month>#{NUMBER_RE})月(?<day>#{NUMBER_RE})日
    \s*
    (?:#{WDAY_RE})?
    \s*
    (?:#{TIMESLOT_RE})?
  /x

  DAY_RE = /(?:#{DAY_RE1})|(?:#{DAY_RE2})|(?:#{DAY_RE3})/x

  # NOTE: Use `(?!(?:間)|(?:ほど))` to reject `~日間` and `~日ほど`
  ONLY_DAY_RE = /
    (?<day>#{NUMBER_RE})日
      (?!(?:間)|(?:ほど))
    \s*
    (?:#{WDAY_RE})?
    \s*
    (?:#{TIMESLOT_RE})?
  /x

  RE = /(?:#{DAY_RE})|(?:#{ONLY_DAY_RE})/x

  class << self
    # @param [String] body
    # @param [Integer | NilClass] fallback_month
    # @param [Integer | NilClass] fallback_year
    # @param [Boolean] debug
    # @return [[String], [[Date, DateTime | NilClass, DateTime | NilClass]] matched strings and dates
    def extract(body, fallback_month: nil, fallback_year: nil, debug: false)
      today = Date.today
      fallback_month ||= Date.today.month
      fallback_year  ||= Date.today.year

      day_matches = get_match_and_positions(body, RE)  # [[MatchData, start, end], [...], ...]

      day_with_hours = days_from_matches(day_matches.map(&:first), fallback_month, fallback_year, debug: debug)  # [[MatchData, Date, DateTime, DateTime], [MatchData, Date, DateTime, nil]...]
      day_with_hours_size = day_matches.size

      timeslots_container = Array.new(day_with_hours_size) { Array.new }  # contains timeslots in each day

      timeslot_matches = get_match_and_positions(body, TIMESLOT_RE)  # [[MatchData, start, end], [...], ...]
      timeslot_matches.each do |(timeslot_match, start_pos, end_pos)|
        i = 0  # index of left_day

        while i < day_with_hours_size
          left_day = day_with_hours[i]
          if left_day[1].nil?  # If failed to `Date.new(~)`, nil is set to left_day[1] which is `Date`
            i += 1
            next end

          right_day = day_with_hours[i+1]
          if !right_day.nil? && right_day[1].nil?  # When failed to `Date.new(~)`
            right_day = day_with_hours[i+2]
          end

          if right_day.nil?  # left_day is on the last
            # Check if timeslot is on the right of left_day
            if left_day[0].end(0) <= start_pos
              timeslots_container[i].push timeslot_match
            end
          else
            # Check if timeslot is between left_day and right_day
            if left_day[0].end(0) <= start_pos && (end_pos - 1) < right_day[0].begin(0)
              timeslots_container[i].push timeslot_match
            end
          end

          i += 1
        end
      end

      days_from_timeslots = days_from_timeslot_matches(timeslots_container, day_with_hours)  # days contains day whidh has same index with timeslots_container

      result_datetimes = days_from_timeslots.map { |(match, day, start_t, end_t)| [day, start_t, end_t] }
      result_strs      = days_from_timeslots.map { |(match, _, _, _)| match&.[](0) }

      if !debug  # Reject nil dates
        exists           = result_datetimes.map { |arr| !arr[0].nil? }
        result_strs      = result_strs.select.with_index { |str, i| exists[i] }
        result_datetimes = result_datetimes.select.with_index { |arr, i| exists[i] }
        [result_strs, result_datetimes]
      else
        [result_strs, result_datetimes]
      end
    end

  private

    def get_match_and_positions(body, re)
      body.to_enum(:scan, re).map { [Regexp.last_match, Regexp.last_match.begin(0), Regexp.last_match.end(0)] }
    end

    def get_hour_from_timeslot_match(match)
      begin
        start_hour = to_downer_letter(match[:start_hour])
      rescue
        start_hour = nil
      end

      begin
        start_min = to_downer_letter(match[:start_min])
      rescue
        if match.names.include?('start_half_hour_unit') && match[:start_half_hour_unit] == '半'
          start_min = 30
        else
          start_min = nil
        end
      end

      begin
        end_hour = to_downer_letter(match[:end_hour])
      rescue
        end_hour = nil
      end

      begin
        end_min = to_downer_letter(match[:end_min])
      rescue
        if match.names.include?('end_half_hour_unit') && match[:end_half_hour_unit] == '半'
          end_min = 30
        else
          end_min = nil
        end
      end

      [start_hour, start_min, end_hour, end_min]
    end

    def create_datetime_if_exists(year, month, day, hour, min)
      if !hour.nil?
        begin
          result = DateTime.new(year, month, day, hour.to_i, min.to_i)
        rescue
          result = nil
        end
      else
        result = nil
      end
      result
    end

    # @return [[MatchData, Date | NilClass, DateTime | NilClass, DateTime | NilClass]]
    # If month is not specified, fallback_month is used as month. This value is
    # updated by discovering other month specification. Same for fallback_year.
    def days_from_matches(matches, fallback_month, fallback_year, debug: false)
      matches.map do |match|
        begin
          year = to_downer_letter(match[:year])
          fallback_year = year
        rescue
          year = fallback_year
        end

        # When ONLY_DAY_RE is used, month is nil
        begin
          month = to_downer_letter(match[:month]).to_i
          fallback_month = month
        rescue
          month = fallback_month
        end

        day = to_downer_letter(match[:day]).to_i

        start_hour, start_min, end_hour, end_min = get_hour_from_timeslot_match(match)

        begin
          date = Date.new(year, month, day)
        rescue
          date = nil
        end

        start_t = create_datetime_if_exists(year, month, day, start_hour, start_min)
        end_t   = create_datetime_if_exists(year, month, day, end_hour, end_min)

        if !date.nil?
          [match, date, start_t, end_t]
        else
          [match, nil, nil, nil]
        end
      end
    end

    # days contains day whidh has same index with timeslots_container
    def days_from_timeslot_matches(timeslots_container, day_with_hours)
      result = []

      day_with_hours.each_with_index do |day_with_hour, i|
        result.push(day_with_hour)
        _, day, _, _ = day_with_hour  #
        next if day.nil?

        timeslot_matches = timeslots_container[i]
        next if (timeslot_matches.size == 0)

        timeslot_matches.each do |timeslot_match|
          start_hour, start_min, end_hour, end_min = get_hour_from_timeslot_match(timeslot_match)

          start_t = create_datetime_if_exists(day.year, day.month, day.day, start_hour, start_min)
          end_t   = create_datetime_if_exists(day.year, day.month, day.day, end_hour, end_min)

          result.push([timeslot_match, day, start_t, end_t])
        end
      end

      result
    end

    def to_downer_letter(upper_or_downer_letter)
      upper_or_downer_letter.split('').map do |c|
        if /[０-９]/.match(c)
          (c.ord - "０".ord).to_s
        else
          c
        end
      end.join
    end
  end
end

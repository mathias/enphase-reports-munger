require "csv"
require "optparse"

class EnphaseMunger
  def initialize(options)
    @monthly = options[:monthly]
    @input = options[:input]
    @output_file_path = "enphase_monthly.csv"
  end

  def run
    input_data = parse_csv

    weekly_ranges = input_data.map do |row|
      hdata = row.to_h

      start_and_end = hdata["Date/Time"].split(" - ")
      start = Date.strptime(start_and_end[0], '%m/%d/%Y')
      end_date =Date.strptime(start_and_end[1], '%m/%d/%Y')

      # {"Date/Time"=>"10/11/2023 - 10/17/2023", "Energy Produced (Wh)"=>"100081", "Energy Consumed (Wh)"=>"140994", "Exported to Grid (Wh)"=>"59327", "Imported from Grid (Wh)"=>"100245"}

      {
        start: start,
        end: end_date,
        energy_produced_wh: hdata["Energy Produced (Wh)"].to_i,
        energy_consumed_wh: hdata["Energy Consumed (Wh)"].to_i,
        energy_exported_wh: hdata["Exported to Grid (Wh)"].to_i,
        energy_imported_wh: hdata["Imported from Grid (Wh)"].to_i
      }
    end

    monthly_ranges = weekly_ranges.reduce({}) do |memo, weekly|
      month = weekly[:start].month
      year = weekly[:start].year
      month_year_string = "#{month}-#{year}"

      if memo[month_year_string]
        this_rec = memo[month_year_string]
        this_rec[:energy_produced_wh] += weekly[:energy_produced_wh]
        this_rec[:energy_consumed_wh] += weekly[:energy_consumed_wh]
        this_rec[:energy_exported_wh] += weekly[:energy_exported_wh]
        this_rec[:energy_imported_wh] += weekly[:energy_imported_wh]
      else
        new_monthly = weekly.except(:start).except(:end)
        memo[month_year_string] = new_monthly
      end
      memo
    end

    kwh_monthly = monthly_ranges.map do |k, v|
      {
        month: k,
        energy_produced_kwh: wh_to_kwh(v[:energy_produced_wh]),
        energy_consumed_kwh: wh_to_kwh(v[:energy_consumed_wh]),
        energy_exported_kwh: wh_to_kwh(v[:energy_exported_wh]),
        energy_imported_kwh: wh_to_kwh(v[:energy_imported_wh])
      }
    end

    #puts kwh_monthly.inspect
    headers = kwh_monthly.first.keys

    write_csv(kwh_monthly, headers)
  end

  def wh_to_kwh(value) # formatted string returned
    if value.is_a? String
      value = value.to_i
    end

    kwh_value = value / 1000.0

    "%0.2f" % kwh_value
  end

  private

  def parse_csv
    return CSV.read(@input, headers: true)
  end

  def write_csv(arry, headers)
    CSV.open(@output_file_path, 'w', headers: headers, write_headers: true) do |csv|
      arry.each { |a| csv << a }
    end
  end
end

if !ENV["TEST"].nil?
  require "minitest/autorun"

class EnphaseMungerTest < Minitest::Test

  def test_wh_to_kwh
    munger = EnphaseMunger.new({})
    assert_equal("183.37", munger.wh_to_kwh(183370))
  end
end

else

  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: munger.rb [options]"

    opts.on("-f", "--input FILE", "Input FILE for processing") do |file|
      options[:input] = file
    end

    opts.on("-m", "--monthly", "Run monthly totals") do |m|
      options[:monthly] = true
    end
  end.parse!

  EnphaseMunger.new(options).run
end

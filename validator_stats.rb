#!/usr/bin/env ruby

require 'csv'
require 'net/http'
require 'json'
require 'uri'

# Validator statistics collector for Aztec network
# Fetches validator data from dashtec.xyz API and saves to CSV
class ValidatorStatsCollector
  API_BASE_URL = 'https://dashtec.xyz/api/search'
  INPUT_FILE = 'stepa_validator.csv'
  OUTPUT_FILE = 'validator_statistics.csv'
  
  def initialize
    @results = []
  end
  
  # Main method to collect statistics
  def collect_stats
    puts "Starting validator statistics collection..."
    
    addresses = read_validator_addresses
    puts "Found #{addresses.length} validator addresses"
    
    # Process each validator
    addresses.each_with_index do |address, index|
      puts "Processing validator #{index + 1}/#{addresses.length}: #{address}"
      
      begin
        stats = fetch_validator_stats(address)
        @results << stats
        
        # Add small delay to avoid overwhelming the API
        sleep(0.5)
      rescue => e
        puts "Error processing #{address}: #{e.message}"
        # Add error entry to maintain consistent output
        @results << create_error_entry(address, e.message)
      end
    end
    
    save_to_csv
    puts "Statistics collection completed. Results saved to #{OUTPUT_FILE}"
  end
  
  private
  
  # Read validator addresses from CSV file
  def read_validator_addresses
    addresses = []
    
    unless File.exist?(INPUT_FILE)
      raise "Input file #{INPUT_FILE} not found!"
    end
    
    CSV.foreach(INPUT_FILE, headers: true) do |row|
      address = row['address']&.strip
      addresses << address if address && !address.empty?
    end
    
    addresses
  end
  
  # Fetch validator statistics from API
  def fetch_validator_stats(address)
    uri = URI("#{API_BASE_URL}?q=#{address}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30
    
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'Aztec Validator Stats Collector'
    
    response = http.request(request)
    
    unless response.code == '200'
      raise "HTTP #{response.code}: #{response.message}"
    end
    
    data = JSON.parse(response.body)
    parse_validator_data(address, data)
  end
  
  # Parse validator data from API response
  def parse_validator_data(address, data)
    validators = data['validators'] || []
    
    if validators.empty?
      return create_not_found_entry(address)
    end
    
    # Take the first validator (should be the matching one)
    validator = validators.first
    
    {
      address: address,
      index: validator['index'] || 'N/A',
      status: validator['status'] || 'N/A',
      balance: validator['balance'] || '0',
      balance_eth: format_balance_in_eth(validator['balance']),
      attestation_success: validator['attestationSuccess'] || 'N/A',
      proposal_success: validator['proposalSuccess'] || 'N/A',
      last_proposed: validator['lastProposed'] || 'N/A',
      performance_score: validator['performanceScore'] || 0,
      total_attestations_succeeded: validator['totalAttestationsSucceeded'] || 0,
      total_attestations_missed: validator['totalAttestationsMissed'] || 0,
      total_blocks_proposed: validator['totalBlocksProposed'] || 0,
      total_blocks_mined: validator['totalBlocksMined'] || 0,
      total_blocks_missed: validator['totalBlocksMissed'] || 0,
      rank: validator['rank'] || 'N/A',
      error: nil
    }
  end
  
  # Create entry for validator not found in API
  def create_not_found_entry(address)
    {
      address: address,
      index: 'NOT_FOUND',
      status: 'NOT_FOUND',
      balance: '0',
      balance_eth: '0',
      attestation_success: 'N/A',
      proposal_success: 'N/A',
      last_proposed: 'N/A',
      performance_score: 0,
      total_attestations_succeeded: 0,
      total_attestations_missed: 0,
      total_blocks_proposed: 0,
      total_blocks_mined: 0,
      total_blocks_missed: 0,
      rank: 'N/A',
      error: 'Validator not found in API'
    }
  end
  
  # Create entry for error cases
  def create_error_entry(address, error_message)
    {
      address: address,
      index: 'ERROR',
      status: 'ERROR',
      balance: '0',
      balance_eth: '0',
      attestation_success: 'N/A',
      proposal_success: 'N/A',
      last_proposed: 'N/A',
      performance_score: 0,
      total_attestations_succeeded: 0,
      total_attestations_missed: 0,
      total_blocks_proposed: 0,
      total_blocks_mined: 0,
      total_blocks_missed: 0,
      rank: 'N/A',
      error: error_message
    }
  end
  
  # Format balance from wei to ETH
  def format_balance_in_eth(balance_wei)
    return '0' unless balance_wei && balance_wei.is_a?(String)
    
    begin
      # Convert from wei to ETH (divide by 10^18)
      balance_float = balance_wei.to_f / 1_000_000_000_000_000_000
      balance_float.round(4).to_s
    rescue
      '0'
    end
  end
  
  # Save results to CSV file
  def save_to_csv
    CSV.open(OUTPUT_FILE, 'w', write_headers: true, headers: csv_headers) do |csv|
      @results.each do |result|
        csv << [
          result[:address],
          result[:index],
          result[:status],
          result[:balance],
          result[:balance_eth],
          result[:attestation_success],
          result[:proposal_success],
          result[:last_proposed],
          result[:performance_score],
          result[:total_attestations_succeeded],
          result[:total_attestations_missed],
          result[:total_blocks_proposed],
          result[:total_blocks_mined],
          result[:total_blocks_missed],
          result[:rank],
          result[:error]
        ]
      end
    end
  end
  
  # CSV headers
  def csv_headers
    [
      'address',
      'index',
      'status',
      'balance_wei',
      'balance_eth',
      'attestation_success_rate',
      'proposal_success_rate',
      'last_proposed',
      'performance_score',
      'total_attestations_succeeded',
      'total_attestations_missed',
      'total_blocks_proposed',
      'total_blocks_mined',
      'total_blocks_missed',
      'rank',
      'error'
    ]
  end
end

# Main execution
if __FILE__ == $0
  begin
    collector = ValidatorStatsCollector.new
    collector.collect_stats
  rescue => e
    puts "Fatal error: #{e.message}"
    puts e.backtrace if ENV['DEBUG']
    exit 1
  end
end

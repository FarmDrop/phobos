require 'spec_helper'

RSpec.describe Phobos do
  describe '.configure' do
    it 'creates the configuration obj' do
      Phobos.instance_variable_set(:@config, nil)
      Phobos.configure(phobos_config_path)
      expect(Phobos.config).to_not be_nil
      expect(Phobos.config.kafka).to_not be_nil
    end

    context 'when using erb syntax in configuration file' do
      it 'parses it correctly' do
        Phobos.instance_variable_set(:@config, nil)
        Phobos.configure('spec/fixtures/phobos_config.yml.erb')

        expect(Phobos.config).to_not be_nil
        expect(Phobos.config.kafka.client_id).to eq('InjectedThroughERB')
      end
    end

    context 'when providing hash with configuration settings' do
      it 'parses it correctly' do
        configuration_settings = {
          kafka: { client_id: 'client_id' },
          logger: { file: 'log/phobos.log' }
        }

        Phobos.instance_variable_set(:@config, nil)
        Phobos.configure(configuration_settings)

        expect(Phobos.config).to_not be_nil
        expect(Phobos.config.kafka.client_id).to eq('client_id')
        expect(Phobos.config.logger.file).to eq('log/phobos.log')
      end
    end
  end

  describe '.create_kafka_client' do
    before { Phobos.configure(phobos_config_path) }

    it 'returns a new kafka client already configured' do
      Phobos.config.logger.ruby_kafka = nil
      Phobos.configure_logger

      expect(Kafka)
        .to receive(:new)
        .with(hash_including(Phobos.config.kafka.to_hash.merge(logger: nil)))
        .and_return(:kafka_client)

      expect(Phobos.create_kafka_client).to eql :kafka_client
    end

    describe 'when "logger.ruby_kafka" is configured' do
      before do
        Phobos.config.logger.ruby_kafka = Phobos::DeepStruct.new(level: 'info')
        Phobos.configure_logger
      end

      it 'configures "logger"' do
        expect(Kafka)
          .to receive(:new)
          .with(hash_including(Phobos.config.kafka.to_hash.merge(logger: instance_of(Logging::Logger))))

        Phobos.create_kafka_client
      end
    end
  end

  describe '.create_exponential_backoff' do
    it 'creates a configured ExponentialBackoff' do
      expect(Phobos.create_exponential_backoff).to be_a(ExponentialBackoff)
    end

    it 'allows backoff times to be overridden' do
      backoff = Phobos.create_exponential_backoff(min_ms: 1234000, max_ms: 5678000)
      expect(backoff).to be_a(ExponentialBackoff)
      expect(backoff.instance_variable_get(:@minimal_interval)).to eq(1234)
      expect(backoff.instance_variable_get(:@maximum_elapsed_time)).to eq(5678)
    end
  end

  describe '.logger' do
    before do
      STDOUT.sync = true
      Phobos.silence_log = false
    end

    context 'without a file configured' do
      it 'writes only to STDOUT' do
        Phobos.config.logger.file = nil
        expect { Phobos.configure_logger }.to_not raise_error

        output = capture(:stdout) { Phobos.logger.info('log-to-stdout') }
        expect(output).to eql output
      end
    end

    context 'with "config.logger.file" defined' do
      it 'writes to the logger file' do
        Phobos.config.logger.file = 'spec/spec.log'
        expect { Phobos.configure_logger }.to_not raise_error

        Phobos.logger.info('log-to-file')
        expect(File.read('spec/spec.log')).to match /log-to-file/
        File.delete(Phobos.config.logger.file)
      end
    end
  end
end

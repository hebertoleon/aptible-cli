require 'aptible/auth'
require 'thor'
require 'json'

require_relative 'helpers/token'
require_relative 'helpers/operation'
require_relative 'helpers/environment'
require_relative 'helpers/app'
require_relative 'helpers/database'
require_relative 'helpers/env'

require_relative 'subcommands/apps'
require_relative 'subcommands/config'
require_relative 'subcommands/db'
require_relative 'subcommands/domains'
require_relative 'subcommands/logs'
require_relative 'subcommands/ps'
require_relative 'subcommands/rebuild'
require_relative 'subcommands/restart'
require_relative 'subcommands/ssh'

module Aptible
  module CLI
    TOKEN_EXPIRY_WITH_OTP = 12 * 60 * 60  # 12 hours

    class Agent < Thor
      include Thor::Actions

      include Helpers::Token
      include Subcommands::Apps
      include Subcommands::Config
      include Subcommands::DB
      include Subcommands::Domains
      include Subcommands::Logs
      include Subcommands::Ps
      include Subcommands::Rebuild
      include Subcommands::Restart
      include Subcommands::SSH

      # Forward return codes on failures.
      def self.exit_on_failure?
        true
      end

      desc 'version', 'Print Aptible CLI version'
      def version
        puts "aptible-cli v#{Aptible::CLI::VERSION}"
      end

      desc 'login', 'Log in to Aptible'
      option :email
      option :password
      option :otp_token, desc: 'A token generated by your second-factor app'
      def login
        email = options[:email] || ask('Email: ')
        password = options[:password] || ask('Password: ', echo: false)
        puts ''

        token_options = { email: email, password: password }

        otp_token = options[:otp_token]
        token_options[:otp_token] = otp_token if otp_token

        begin
          token_options[:expires_in] = TOKEN_EXPIRY_WITH_OTP \
              if token_options[:otp_token]
          token = Aptible::Auth::Token.create(token_options)
        rescue OAuth2::Error => e
          if e.code == 'otp_token_required'
            token_options[:otp_token] = options[:otp_token] ||
                                        ask('2FA Token: ')
            retry
          end

          raise Thor::Error, 'Could not authenticate with given credentials: ' \
                             "#{e.code}"
        end

        save_token(token.access_token)
        puts "Token written to #{token_file}"
      end

      private

      def deprecated(msg)
        say "DEPRECATION NOTICE: #{msg}"
        say 'Please contact support@aptible.com with any questions.'
      end
    end
  end
end

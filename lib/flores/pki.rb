# encoding: utf-8
# This file is part of ruby-flores.
# Copyright (C) 2015 Jordan Sissel
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require "flores/namespace"
require "flores/random"
require "flores/pki/csr"
require "English"
require "openssl"

module Flores::PKI
  DEFAULT_CERTIFICATE_OPTIONS = {
    :duration => 100..86400,
    :key_size => 1024,
    :exponent => 65537,
    :want_signature_ability => false
  }

  class << self
    # Generate a random serial number for a certificate.
    def random_serial
      # RFC5280 (X509) says:
      # > 4.1.2.2.  Serial Number 
      # > Certificate users MUST be able to handle serialNumber values up to 20 octets
      Flores::Random.integer(1..9).to_s + Flores::Random.iterations(0..19).collect { Flores::Random.integer(0..9) }.join
    end

    # Generate a valid certificate with sane random values.
    #
    # By default this method use `CN=localhost` as the default subject and a 1024 bits encryption
    # key for the certificate, you can override the defaults by specifying a subject and the
    # key size in the options hash.
    #
    # Example:
    #
    #     Flores::PKI.generate("CN=localhost", { :key_size => 2048 }
    # 
    # @params subject [String] Certificate subject
    # @params opts [Hash] Options
    # @return [OpenSSL::X509::Certificate, OpenSSL::Pkey::RSA]
    def generate(subject = "CN=localhost", opts = {})
      key_size = opts.fetch(:key_size, DEFAULT_CERTIFICATE_OPTIONS[:key_size])
      key = OpenSSL::PKey::RSA.generate(key_size, DEFAULT_CERTIFICATE_OPTIONS[:exponent])

      certificate_duration = Flores::Random.number(DEFAULT_CERTIFICATE_OPTIONS[:duration])

      csr = Flores::PKI::CertificateSigningRequest.new
      csr.subject = subject
      csr.public_key = key.public_key
      csr.start_time = Time.now
      csr.expire_time = csr.start_time + certificate_duration
      csr.signing_key = key
      csr.want_signature_ability = true
      certificate = csr.create

      return [certificate, key]
    end

    def self.chain_certificates(*certificates)
      certificates.join("\n")
    end

    def self.create_intermediate_certificate(subject, signing_certificate, signing_private_key, options  = {})
      create_a_signed_certificate(subject, signing_certificate, signing_private_key, options.merge({ :want_signature_ability => true }))
    end

    def self.create_client_certicate(subject, signing_certificate, signing_private_key, options = {})
      create_a_signed_certificate(subject, signing_certificate, signing_private_key, options)
    end

    private
    def self.create_a_signed_certificate(subject, signing_certificate, signing_private_key, options = {})
      options = DEFAULT_CERTIFICATE_OPTIONS.merge(options)

      client_key = OpenSSL::PKey::RSA.new(options[:key_size], options[:exponent])

      certificate_duration = Flores::Random.number(DEFAULT_CERTIFICATE_OPTIONS[:duration])

      csr = Flores::PKI::CertificateSigningRequest.new
      csr.start_time = Time.now
      csr.expire_time = csr.start_time + certificate_duration
      csr.public_key = client_key.public_key
      csr.subject = subject
      csr.signing_key = signing_private_key
      csr.signing_certificate = signing_certificate
      csr.want_signature_ability = options[:want_signature_ability]

      [csr.create, client_key]
    end
  end
end  # Flores::PKI

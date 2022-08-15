# encoding: utf-8
# This file is part of ruby-flores.
# Copyright (C) 2015 Jordan Sissel
# 

require "flores/namespace"
require "flores/random"
require "flores/pki/csr"
require "English"
require "openssl"

module Flores::PKI
  GENERATE_DEFAULT_KEY_SIZE = 1024
  GENERATE_DEFAULT_EXPONENT = 65537
  GENERATE_DEFAULT_DURATION_RANGE = 1..86400

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
      key_size = opts.fetch(:key_size, GENERATE_DEFAULT_KEY_SIZE)
      key = OpenSSL::PKey::RSA.generate(key_size, GENERATE_DEFAULT_EXPONENT)

      certificate_duration = Flores::Random.number(GENERATE_DEFAULT_DURATION_RANGE)

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
  end
end  # Flores::PKI

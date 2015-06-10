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
require "English"
require "openssl"

module Flores::PKI
  # A certificate signing request.
  #
  # From here, you can configure a certificate to be created based on your
  # desired configuration.
  #
  # Example making a root CA:
  #
  #     key = OpenSSL::PKey::RSA.generate(4096, 65537)
  #     csr = Flores::PKI::CertificateSigningRequest.new
  #     csr.subject = "OU=Fancy Pants Inc."
  #     certificate = csr.create_root(key)
  #
  # Example making an intermediate CA:
  #     
  #     root_key = OpenSSL::PKey::RSA.generate(4096, 65537)
  #     root_csr = Flores::PKI::CertificateSigningRequest.new
  #     root_csr.subject = "OU=Fancy Pants Inc."
  #     root_csr.public_key = root_key.public
  #     root_certificate = csr.create_root(root_key)
  #
  #     intermediate_key = OpenSSL::PKey::RSA.generate(4096, 65537)
  #     intermediate_csr = Flores::PKI::CertificateSigningRequest.new
  #     intermediate_csr.public_key = intermediate_key.public
  #     intermediate_csr.subject = "OU=Fancy Pants Inc. Intermediate 1"
  #     intermediate_certificate = csr.create_intermediate(root_certificate, root_key)
  class CertificateSigningRequest
    class InvalidData < StandardError; end
    class InvalidSubject < InvalidData; end
    class InvalidTime < InvalidData; end

    def validate_subject(value)
      OpenSSL::X509::Name.parse(value)
    rescue OpenSSL::X509::NameError => e
      raise InvalidSubject, "Invalid subject '#{value}'. (#{e})"
    rescue TypeError => e
      # Bug(?) in MRI 2.1.6(?)
      raise InvalidSubject, "Invalid subject '#{value}'. (#{e})"
    end

    def subject=(value)
      @subject = validate_subject(value)
    end

    attr_reader :subject

    def subject_alternates=(*values)
      @subject_alternates = values.collect(&:validate_subject)
    end

    attr_reader :subject_alternates

    def public_key=(value)
      @public_key = validate_public_key(value)
    end

    def validate_public_key(value)
      raise InvalidData, "public key must be a OpenSSL::PKey::PKey" unless value.is_a? OpenSSL::PKey::PKey
      value
    end

    attr_reader :public_key

    def start_time=(value)
      @start_time = validate_time(value)
    end

    attr_reader :start_time

    def expire_time=(value)
      @expire_time = validate_time(value)
    end

    attr_reader :expire_time

    def validate_time(value)
      raise InvalidTime, "#{value.inspect} (class #{value.class.name})" unless value.is_a?(Time)
      value
    end

    def certificate
      return @certificate  if @certificate
      @certificate = OpenSSL::X509::Certificate.new

      # RFC5280
      # > 4.1.2.1.  Version
      # > version MUST be 3 (value is 2).
      #
      # Version value of '2' means a v3 certificate.
      @certificate.version = 2

      @certificate.subject = subject
      @certificate.public_key = public_key
      @certificate.not_before = start_time
      @certificate.not_after = expire_time
      @certificate
    end

    def random_serial
      # RFC5280 (X509) says:
      # > 4.1.2.2.  Serial Number 
      # > Certificate users MUST be able to handle serialNumber values up to 20 octets
      Flores::Random.iterations(1..20).collect { Flores::Random.integer(0..9) }.join
    end

    def default_digest_method
      OpenSSL::Digest::SHA256.new
    end

    # Creates a new root certificate authority
    #
    # - signing_key : probably OpenSSL::PKey::RSA
    # - digest_method : An OpenSSL::Digest instance.
    #
    # Example:
    #
    #     key = OpenSSL::PKey::RSA.generate(4096, 65537) 
    #     csr.create_root(key.private_key, OpenSSL::Digest::SHA256.new)
    #
    # A root certificate authority has two basic properties:
    # 1) It is signed by itself
    # 2) It can sign certificates
    #
    def create_root(signing_key, digest_method = default_digest_method, serial = random_serial)
      extensions = OpenSSL::X509::ExtensionFactory.new
      extensions.subject_certificate = certificate
      extensions.issuer_certificate = certificate

      certificate.add_extension(extensions.create_extension("subjectKeyIdentifier", "hash", true))
      certificate.add_extension(extensions.create_extension("authorityKeyIdentifier", "keyid:always,issuer", true))
      certificate.add_extension(extensions.create_extension("basicConstraints", "CA:TRUE", true))
      # Rough googling seems to indicate at least keyCertSign is required for CA and intermediate certs.
      certificate.add_extension(extensions.create_extension("keyUsage", "keyCertSign, cRLSign, digitalSignature", true))

      certificate.serial = OpenSSL::BN.new(serial)
      certificate.sign(signing_key, digest_method)
      certificate
    end

    # Creates a new intermediate certificate authority
    #
    # An intermediate certificate authority is a certificate that has two basic properties:
    # 1) It is signed by another certificate (root or intermediate) authority.
    # 2) It can sign certificates
    def create_intermediate(signing_certificate, signing_key, digest_method = default_digest_method, serial = random_serial)
      extensions = OpenSSL::X509::ExtensionFactory.new
      extensions.subject_certificate = certificate
      extensions.issuer_certificate = signing_certificate

      certificate.add_extension(extensions.create_extension("subjectKeyIdentifier", "hash", true))
      certificate.add_extension(extensions.create_extension("authorityKeyIdentifier", "keyid:always,issuer", true))
      certificate.add_extension(extensions.create_extension("basicConstraints", "CA:TRUE", true))
      # Rough googling seems to indicate at least keyCertSign is required for CA and intermediate certs.
      certificate.add_extension(extensions.create_extension("keyUsage", "keyCertSign, cRLSign, digitalSignature", true))
      certificate.serial = OpenSSL::BN.new(serial)

      certificate.sign(signing_key, digest_method)
      certificate
    end

    def create(signing_certificate, signing_key, digest_method = default_digest_method, serial = random_serial)
      extensions = OpenSSL::X509::ExtensionFactory.new
      extensions.subject_certificate = certificate
      extensions.issuer_certificate = signing_certificate

      certificate.add_extension(extensions.create_extension("subjectKeyIdentifier", "hash", true))
      certificate.add_extension(extensions.create_extension("authorityKeyIdentifier", "keyid,issuer:always", true))
      certificate.add_extension(extensions.create_extension("basicConstraints", "CA:FALSE", true))
      certificate.add_extension(extensions.create_extension("keyUsage", "digitalSignature, keyEncipherment", true))
      certificate.add_extension(extensions.create_extension("extendedKeyUsage", "serverAuth", false))

      certificate.serial = OpenSSL::BN.new(serial)
      certificate.sign(signing_key, digest_method)
      certificate
    end

    def create_self_signed(signing_key, digest_method = default_digest_method, serial = random_serial)
      serial = random_serial if serial.nil?

      extensions = OpenSSL::X509::ExtensionFactory.new
      extensions.subject_certificate = certificate
      extensions.issuer_certificate = certificate

      certificate.add_extension(extensions.create_extension("subjectKeyIdentifier", "hash", true))
      certificate.add_extension(extensions.create_extension("authorityKeyIdentifier", "keyid,issuer:always", true))
      certificate.add_extension(extensions.create_extension("basicConstraints", "CA:FALSE", true))
      certificate.add_extension(extensions.create_extension("keyUsage", "digitalSignature, keyEncipherment", true))
      certificate.add_extension(extensions.create_extension("extendedKeyUsage", "serverAuth", false))

      certificate.serial = OpenSSL::BN.new(serial)
      certificate.sign(signing_key, digest_method)
      certificate
    end
  end # class CertificateSigningRequest
end  # Flores::PKI

#!/usr/bin/env ruby
# frozen_string_literal: true
# Ported from rwrife/rise-log's cook-console-derived release pipeline.
require 'base64'
require 'json'
require 'openssl'

key_path, key_id, issuer_id = ARGV
abort('usage: asc_jwt.rb KEY_PATH KEY_ID ISSUER_ID') unless key_path && key_id && issuer_id

encode = ->(data) { Base64.urlsafe_encode64(data, padding: false) }
header = { alg: 'ES256', kid: key_id, typ: 'JWT' }
claims = { iss: issuer_id, aud: 'appstoreconnect-v1', exp: Time.now.to_i + 1200 }
input = "#{encode.call(header.to_json)}.#{encode.call(claims.to_json)}"
key = OpenSSL::PKey::EC.new(File.read(key_path))
der = key.dsa_sign_asn1(OpenSSL::Digest::SHA256.digest(input))
r, s = OpenSSL::ASN1.decode(der).value.map { |item| item.value.to_i }
# JWS ES256 requires 64 raw bytes (r||s), not OpenSSL's ASN.1 DER signature.
signature = [r.to_s(16).rjust(64, '0') + s.to_s(16).rjust(64, '0')].pack('H*')
puts "#{input}.#{encode.call(signature)}"

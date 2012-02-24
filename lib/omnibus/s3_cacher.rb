require 'singleton'
require 'fileutils'
require 'omnibus/fetchers'

module Omnibus

  class Config
    include Singleton

    attr_accessor :cache_dir

    attr_accessor :s3_bucket
    attr_accessor :s3_access_key
    attr_accessor :s3_secret_key

    attr_accessor :use_s3_caching

  end

  def self.config
    Config.instance
  end

  def self.configure
    yield config
  end

  module S3Tasks
    extend Rake::DSL

    def self.define!
      require 'uber-s3'

      namespace :s3 do
        desc "List source packages which have the correct source package in the S3 cache"
        task :existing do
          S3Cache.new.list.each {|s| puts s.name}
        end

        desc "List all cached files (by S3 key)"
        task :list do
          S3Cache.new.list_by_key.each {|k| puts k}
        end

        desc "Lists source packages that are required but not yet cached"
        task :missing do
          S3Cache.new.missing.each {|s| puts s.name}
        end

        desc "Fetches missing source packages to local tmp dir"
        task :fetch do
          S3Cache.new.fetch_missing
        end

        desc "Populate the S3 Cache"
        task :populate do
          S3Cache.new.populate
        end

      end
    rescue LoadError

      desc "S3 tasks not available"
      task :s3 do
        puts(<<-F)
The `uber-s3` gem is required to cache new source packages in S3.
F
      end
    end
  end

  class S3Cache

    class InsufficientSpecification < ArgumentError
    end

    def initialize
      @client = UberS3.new(
        :access_key         => config.s3_access_key,
        :secret_access_key  => config.s3_secret_key,
        :bucket             => config.s3_bucket,
        :adaper             => :net_http
      )
    end

    def log(msg)
      puts "[S3 Cacher] #{msg}"
    end

    def config
      Omnibus.config
    end

    def list
      existing_keys = list_by_key
      tarball_software.select {|s| existing_keys.include?(key_for_package(s))}
    end

    def list_by_key
      bucket.objects('/').map(&:key)
    end

    def missing
      already_cached = list_by_key
      tarball_software.delete_if {|s| already_cached.include?(key_for_package(s))}
    end

    def tarball_software
      Omnibus.library.select {|s| s.source && s.source.key?(:url)}
    end

    def populate
      missing.each do |software|
        fetch(software)

        key = key_for_package(software)
        content = IO.read(software.project_file)

        log "Uploading #{software.project_file} as #{config.s3_bucket}/#{key}"
        @client.store(key, content, :access => :public_read, :content_md5 => software.checksum)
      end
      
    end

    def fetch_missing
      missing.each do |software|
        fetch(software)
      end
    end

    private

    def ensure_cache_dir
      FileUtils.mkdir_p(config.cache_dir)
    end

    def fetch(software)
      log "Fetching #{software.name}"
      fetcher = Fetcher.for(software)
      if fetcher.should_fetch?
        fetcher.download
        fetcher.verify_checksum!
      else
        log "Cached copy up to date, skipping."
      end
    end

    def bucket
      @bucket ||= begin
        b = UberS3::Bucket.new(@client, @client.bucket)
        # creating the bucket is idempotent, make sure it's created:
        @client.connection.put("/")
        b
      end
    end

    def key_for_package(package)
      package.name     or raise InsufficientSpecification, "Software must have a name to cache it in S3 (#{package.inspect})"
      package.version  or raise InsufficientSpecification, "Software must set a version to cache it in S3 (#{package.inspect})"
      package.checksum or raise InsufficientSpecification, "Software must specify a checksum (md5) to cache it in S3 (#{package.inspect})"
      "#{package.name}-#{package.version}-#{package.checksum}"
    end

  end
end
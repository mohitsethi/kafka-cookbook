#
# Cookbook Name:: kafka
# Recipe:: source
#

include_recipe 'kafka::configure'

node.default[:kafka][:scala_version] ||= '2.9.2'
node.default[:kafka][:checksum]      ||= 'f4b7229671aba98dba9a882244cb597aab8a9018631575d28e119725a01cfc9a'
node.default[:kafka][:md5_checksum]  ||= '46b3e65e38f1bde4b6251ea131d905f4'

build_directory    = "#{node[:kafka][:install_dir]}/build"
kafka_src          = "kafka-#{node[:kafka][:version]}-src"
kafka_tar_gz       = "#{kafka_src}.tgz"
download_file      = "#{node[:kafka][:base_url]}/#{node[:kafka][:version]}/#{kafka_tar_gz}"
local_file_path    = "#{Chef::Config[:file_cache_path]}/#{kafka_tar_gz}"
kafka_path         = "kafka_#{node[:kafka][:scala_version]}-#{node[:kafka][:version]}"
kafka_jar          = "#{kafka_path}.jar"
kafka_target_path  = "#{build_directory}/#{kafka_src}/target/RELEASE/#{kafka_path}"
installed_path     = "#{node[:kafka][:install_dir]}/#{kafka_jar}"

unless (already_installed = (File.directory?(build_directory) && File.exists?(installed_path)))
  directory build_directory do
    owner     node[:kafka][:user]
    group     node[:kafka][:group]
    mode      '755'
    action    :create
    recursive true
  end

  remote_file local_file_path do
    source   download_file
    mode     '644'
    checksum node[:kafka][:checksum]
    notifies :create, 'ruby_block[validate-tarball]', :immediately
  end

  ruby_block 'validate-tarball' do
    block do
      checksum = Digest::MD5.file(local_file_path).hexdigest
      unless checksum == node[:kafka][:md5_checksum]
        Chef::Log.fatal!("Downloaded tarball checksum (#{checksum}) does not match known checksum (#{node[:kafka][:md5_checksum]})")
      end
    end
    action :nothing
    notifies :run, 'execute[compile-kafka]', :immediately
  end

  execute 'compile-kafka' do
    cwd   build_directory
    command <<-EOH.gsub(/^\s+/, '')
      tar zxvf #{Chef::Config[:file_cache_path]}/#{kafka_tar_gz}
      cd #{kafka_src}
      ./sbt update
      ./sbt "++#{node[:kafka][:scala_version]} release-zip"
    EOH

    action :nothing
    notifies :run, 'execute[install-kafka]', :immediately
  end

  execute 'install-kafka' do
    user  node[:kafka][:user]
    group node[:kafka][:group]
    cwd   node[:kafka][:install_dir]
    command %{cp -r #{kafka_target_path}/* .}
    action :nothing
  end
end

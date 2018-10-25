#!/usr/bin/ruby

# Copyright 2015 gRPC authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Sample gRPC server that implements the Greeter::Helloworld service.
#
# Usage: $ path/to/greeter_server.rb

this_dir = File.expand_path(File.dirname(__FILE__))
lib_dir = File.join(this_dir, 'lib')
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)

#home_dir = File.expand_path("~")
#ruby_grpc_dir = File.join(home_dir, 'Documents','grpc','src','ruby','lib',"grpc")
#$LOAD_PATH.unshift(ruby_grpc_dir) unless $LOAD_PATH.include?(ruby_grpc_dir)
#
#p $LOAD_PATH
#
#require_relative ruby_grpc_dir.to_s 
require 'grpc'
require 'reflection_services_pb'
require 'reflection_pb'
require 'logging'

module GRPC
  extend Logging.globally
end

Logging.logger.root.appenders = Logging.appenders.stdout
Logging.logger.root.level = :info
Logging.logger['GRPC'].level = :info
Logging.logger['GRPC::ServerInterceptor'].level = :info
Logging.logger['GRPC::ActiveCall'].level = :info
Logging.logger['GRPC::BidiCall'].level = :info

# ReflectionServer implements the ServerReflection template
class ReflectionServer < Grpc::Reflection::V1alpha::ServerReflection::Service
  def server_reflection_info(reflect_req)
    ReflectionEnumerator.new(reflect_req).each_item
  end
end

class ReflectionEnumerator
  @requests
  def initialize(reflect_reqs)
    @requests = reflect_reqs
  end

  def each_item
    return enum_for(:each_item) unless block_given?
    begin
      # send back the earlier messages at this point
      @requests.each do |r|
        # Create a ServiceResponse
        #   User specified or auto generated?
        service_names = ["hello", "world"]
        services = service_names.map do |s| 
          Grpc::Reflection::V1alpha::ServiceResponse.new(:name => s)
        end

        serviceResponse = Grpc::Reflection::V1alpha::ListServiceResponse.new(
          :service => services
        )

        response = Grpc::Reflection::V1alpha::ServerReflectionResponse.new(
          :valid_host => "ruby_reflection_server",
          :original_request => r,
          :list_services_response => serviceResponse
        )
        yield response
      end
    rescue StandardError => e
      fail e # signal completion via an error
    end
  end
end

# main starts an RpcServer that receives requests to GreeterServer at the sample
# server port.
def main
  reflectionInterceptor = TestServerInterceptor.new()
  s = GRPC::RpcServer.new()
  s.add_http2_port('0.0.0.0:50051', :this_port_is_insecure)
  s.handle(ReflectionServer)
  reflectionClass = Grpc::Reflection::V1alpha::ServerReflection::Service
  p reflectionClass.public_methods
  s.run_till_terminated
end

# For testing server interceptors
class TestServerInterceptor < GRPC::ServerInterceptor
  def bidi_streamer(requests:, call:, method:)
    # check if requests contain any ReflectionRequests
    # if using reflection server, the stream should only contain ReflectionRequests
    containsReflectoinRequests = requests.any? do |r| 
      r.instance_of?(Grpc::Reflection::V1alpha::ServerReflectionRequest) 
    end
    if containsReflectoinRequests 
      GRPC.logger.info("Bidi request contains a ReflectionRequest")
    end

    requests.each do |r|
      GRPC.logger.info("Bidi request: #{r}")
    end
    GRPC.logger.info("Received bidi streamer call at method #{method} with requests" \
      " #{requests} for call #{call}")
    call.output_metadata[:interc] = 'from_bidi_streamer'
    yield
  end
end

main
